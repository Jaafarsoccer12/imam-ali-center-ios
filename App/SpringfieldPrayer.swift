import Foundation

/// All wall times refer to the Center, even when the visitor uses another time zone.
enum SpringfieldClock {
    static let zone = TimeZone(identifier: "America/New_York")!
    static let calendar: Calendar = {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = zone
        return result
    }()

    static func clock(_ date: Date) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour = parts.hour ?? 0
        return String(format: "%d:%02d %@", hour % 12 == 0 ? 12 : hour % 12, parts.minute ?? 0, hour < 12 ? "AM" : "PM")
    }

    static func apiDay(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%02d-%02d-%04d", parts.day!, parts.month!, parts.year!)
    }

    static func dateLabel(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: Locale(identifier: "en_US"), calendar: calendar, timeZone: zone)
            .weekday(.wide).month(.wide).day())
    }
}

struct PrayerMoment: Identifiable, Equatable {
    let name: String
    let date: Date
    var id: String { name }
}

enum SpringfieldPrayers {
    static let names = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"]

    static func assemble(_ minutes: [Int], on day: Date) -> [PrayerMoment] {
        guard minutes.count == names.count else { return [] }
        let calendar = SpringfieldClock.calendar
        return zip(names, minutes).compactMap { name, time in
            guard (0..<1440).contains(time),
                  let date = calendar.date(bySettingHour: time / 60, minute: time % 60, second: 0, of: day)
            else { return nil }
            return PrayerMoment(name: name, date: date)
        }
    }

    // The same solar calculation and adjustments as imamalicenter.org/app.js.
    // UTC noon fixes the solar date. Eastern noon supplies the offset for the local day.
    static func localMinutes(on day: Date) -> [Int] {
        let calendar = SpringfieldClock.calendar
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
        let offset = Double(SpringfieldClock.zone.secondsFromGMT(for: noon))
        let julianDay = (noon.timeIntervalSince1970 + offset) / 86_400 + 2_440_587.5
        let century = (julianDay - 2_451_545) / 36_525
        func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
        func degrees(_ radians: Double) -> Double { radians * 180 / .pi }

        let longitude = (280.46646 + century * (36000.76983 + century * 0.0003032)).truncatingRemainder(dividingBy: 360)
        let anomaly = radians(357.52911 + century * (35999.05029 - 0.0001537 * century))
        let eccentricity = 0.016708634 - century * (0.000042037 + 0.0000001267 * century)
        let center = sin(anomaly) * (1.914602 - century * (0.004817 + 0.000014 * century))
            + sin(2 * anomaly) * (0.019993 - 0.000101 * century)
            + sin(3 * anomaly) * 0.000289
        let omega = radians(125.04 - 1934.136 * century)
        let sunLongitude = radians(longitude + center - 0.00569 - 0.00478 * sin(omega))
        let meanObliquity = 23 + (26 + (21.448 - century * (46.815 + century * (0.00059 - century * 0.001813))) / 60) / 60
        let obliquity = radians(meanObliquity + 0.00256 * cos(omega))
        let declination = asin(sin(obliquity) * sin(sunLongitude))
        let y = pow(tan(obliquity / 2), 2)
        let meanLongitude = radians(longitude)
        let equation = 4 * degrees(
            y * sin(2 * meanLongitude) - 2 * eccentricity * sin(anomaly)
            + 4 * eccentricity * y * sin(anomaly) * cos(2 * meanLongitude)
            - 0.5 * y * y * sin(4 * meanLongitude)
            - 1.25 * eccentricity * eccentricity * sin(2 * anomaly)
        )
        let latitude = radians(38.7893)
        let solarNoon = 720 + offset / 60 - 4 * (-77.1872) - equation
        func arcMinutes(altitude: Double) -> Double {
            let cosine = (sin(radians(altitude)) - sin(latitude) * sin(declination)) / (cos(latitude) * cos(declination))
            return degrees(acos(min(1, max(-1, cosine)))) * 4
        }
        let asr = degrees(atan(1 / (1 + tan(abs(latitude - declination)))))
        return [
            solarNoon - arcMinutes(altitude: -17.7),
            solarNoon - arcMinutes(altitude: -0.833),
            solarNoon + 2,
            solarNoon + arcMinutes(altitude: asr),
            solarNoon + arcMinutes(altitude: -4.5),
            solarNoon + arcMinutes(altitude: -14)
        ].map { ((Int($0.rounded()) % 1440) + 1440) % 1440 }
    }

    struct APIResponse: Decodable {
        struct Day: Decodable {
            let timings: [String: String]
            let date: DayDate
            struct DayDate: Decodable {
                struct Gregorian: Decodable { let date: String }
                let gregorian: Gregorian
            }
        }
        let code: Int
        let data: Day
    }

    static func liveMinutes(on day: Date) async throws -> [Int] {
        let key = SpringfieldClock.apiDay(day)
        var endpoint = URLComponents(string: "https://api.aladhan.com/v1/timingsByCity/" + key)!
        endpoint.queryItems = [("city", "Springfield"), ("state", "Virginia"), ("country", "United States"),
                               ("method", "7"), ("school", "0")].map { URLQueryItem(name: $0.0, value: $0.1) }
        var request = URLRequest(url: endpoint.url!, timeoutInterval: 8)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let payload = try JSONDecoder().decode(APIResponse.self, from: data)
        guard payload.code == 200, payload.data.date.gregorian.date == key else { throw URLError(.cannotParseResponse) }
        return try names.map { name in
            let raw = payload.data.timings[name]?.prefix(5).split(separator: ":")
            guard let raw, raw.count == 2, let hour = Int(raw[0]), let minute = Int(raw[1]),
                  (0..<24).contains(hour), (0..<60).contains(minute) else { throw URLError(.cannotParseResponse) }
            return hour * 60 + minute
        }
    }
}
