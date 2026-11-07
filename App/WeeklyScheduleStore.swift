import Foundation
import Combine

struct WeeklyMeeting: Identifiable, Codable, Equatable {
    let name: String
    let speaker: String
    let category: String
    let weekday: Int
    let hour: Int
    let minute: Int
    var location = "Imam Ali Center"
    var id: String { "\(weekday)/\(hour):\(minute)/\(name)" }
    var weekdayLabel: String { ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][weekday - 1] }
    var timeLabel: String { String(format: "%d:%02d %@", hour % 12 == 0 ? 12 : hour % 12, minute, hour < 12 ? "AM" : "PM") }

    func nextOccurrence(after date: Date) -> Date {
        let match = DateComponents(hour: hour, minute: minute, second: 0, weekday: weekday)
        return SpringfieldClock.calendar.nextDate(after: date, matching: match, matchingPolicy: .nextTime)!
    }

    static let regular = [
        WeeklyMeeting(name: "Dua Tawassul", speaker: "Brother Jaafar Al-Sadeq", category: "Supplication", weekday: 3, hour: 19, minute: 0),
        WeeklyMeeting(name: "Dua Kumayl", speaker: "Qari Moqset Moqami", category: "Supplication", weekday: 5, hour: 19, minute: 0),
        WeeklyMeeting(name: "Friday Prayer", speaker: "Sheikh Mustafa Akhound", category: "Congregational prayer", weekday: 6, hour: 13, minute: 10),
        WeeklyMeeting(name: "Qur’an Circle", speaker: "Qari Dr. Komail Sheikhzada", category: "Qur’an", weekday: 6, hour: 18, minute: 0)
    ]
}

// Parse only the weekly list. All cards must have valid fields before replacing the
// displayed schedule; a partial response cannot silently remove familiar programs.
enum WeeklyScheduleParser {
    private final class Node {
        let tag: String
        let classes: Set<String>
        var children = [Node]()
        var text = ""
        init(_ tag: String, attributes: [String: String]) {
            self.tag = tag
            self.classes = Set((attributes["class"] ?? "").split(whereSeparator: { $0.isWhitespace }).map(String.init))
        }
        func child(_ tag: String, class expected: String? = nil) -> Node? {
            let matches = children.filter { node in
                node.tag == tag && (expected.map { node.classes.contains($0) } ?? true)
            }
            return matches.count == 1 ? matches[0] : nil
        }
        var label: String { text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ") }
    }

    private final class Fragment: NSObject, XMLParserDelegate {
        var root: Node?
        var stack = [Node]()

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String]) {
            guard stack.count < 20 else { parser.abortParsing(); return }
            let node = Node(name, attributes: attributes)
            if let parent = stack.last { parent.children.append(node) } else { root = node }
            stack.append(node)
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) { stack.last?.text.append(string) }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
            if let node = stack.popLast() { stack.last?.text.append(node.text) }
        }
    }

    static func parse(_ html: String) -> [WeeklyMeeting]? {
        guard html.utf8.count <= 262_144,
              let start = html.range(of: #"<div\s+class\s*=\s*["']schedule-list["']\s*>"#, options: [.regularExpression, .caseInsensitive]),
              let footer = html.range(of: #"<div\s+class\s*=\s*["']schedule-footer["']"#, options: [.regularExpression, .caseInsensitive], range: start.upperBound..<html.endIndex)
        else { return nil }
        let source = String(html[start.lowerBound..<footer.lowerBound])
        guard source.utf8.count <= 131_072, !source.contains("<!") else { return nil }
        let xml = source.replacingOccurrences(of: "&nbsp;", with: "&#160;")
            .replacingOccurrences(of: "&rsquo;", with: "&#8217;")
            .replacingOccurrences(of: #"&(?![a-zA-Z]+;|#[0-9]+;|#x[0-9A-Fa-f]+;)"#, with: "&amp;", options: .regularExpression)
        let fragment = Fragment()
        let parser = XMLParser(data: Data(xml.utf8))
        parser.delegate = fragment
        parser.shouldResolveExternalEntities = false
        guard parser.parse(), parser.parserError == nil, fragment.stack.isEmpty,
              let list = fragment.root, list.classes.contains("schedule-list"), (1...32).contains(list.children.count)
        else { return nil }
        var meetings = [WeeklyMeeting]()
        for card in list.children {
            guard card.tag == "article", card.classes.contains("schedule-card"),
                  let day = card.child("div", class: "schedule-day"),
                  day.child("small")?.label.uppercased() == "EVERY",
                  let weekday = parseDay(day.child("strong")?.label),
                  let info = card.child("div", class: "schedule-info"),
                  let category = info.child("span", class: "event-type")?.label,
                  let name = info.child("h3")?.label, let speaker = info.child("p")?.label,
                  let meta = card.child("div", class: "schedule-meta"),
                  let location = meta.child("span")?.label,
                  let time = parseTime(meta.child("strong")?.label)
            else { return nil }
            meetings.append(WeeklyMeeting(name: name, speaker: speaker, category: category, weekday: weekday,
                                          hour: time.hour, minute: time.minute, location: location))
        }
        return valid(meetings) ? meetings : nil
    }

    private static func parseDay(_ text: String?) -> Int? {
        guard let day = text?.uppercased() else { return nil }
        let names = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
        return names.firstIndex { $0 == day || String($0.prefix(3)) == day }.map { $0 + 1 }
    }

    private static func parseTime(_ text: String?) -> (hour: Int, minute: Int)? {
        guard let text else { return nil }
        let fields = text.uppercased().split(separator: " ")
        guard fields.count == 2, ["AM", "PM"].contains(fields[1]) else { return nil }
        let numbers = fields[0].split(separator: ":", omittingEmptySubsequences: false)
        guard numbers.count == 2, (1...2).contains(numbers[0].count), numbers[1].count == 2,
              numbers.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let hour = Int(numbers[0]), (1...12).contains(hour), let minute = Int(numbers[1]), (0..<60).contains(minute)
        else { return nil }
        return (hour % 12 + (fields[1] == "PM" ? 12 : 0), minute)
    }

    static func valid(_ meetings: [WeeklyMeeting]) -> Bool {
        (1...32).contains(meetings.count) && Set(meetings.map(\.id)).count == meetings.count && meetings.allSatisfy { item in
            (1...7).contains(item.weekday) && (0..<24).contains(item.hour) && (0..<60).contains(item.minute)
                && [item.name, item.speaker, item.category, item.location].allSatisfy {
                    (1...200).contains($0.count) && !$0.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
                }
        }
    }
}

private final class CenterOrigin: NSObject, URLSessionTaskDelegate {
    static let page = URL(string: "https://imamalicenter.org/")!
    static func isCenter(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.scheme == "https" && url.host?.lowercased() == page.host && (url.port ?? 443) == 443
            && url.user == nil && url.password == nil
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(Self.isCenter(request.url) ? request : nil)
    }
}

@MainActor
final class WeeklyScheduleStore: ObservableObject {
    static let shared = WeeklyScheduleStore()
    @Published private(set) var meetings = WeeklyMeeting.regular

    private struct Snapshot: Codable {
        let date: Date
        let meetings: [WeeklyMeeting]
    }
    private let cacheKey = "center.weeklySchedule.v1"
    private var lastSuccess = Date.distantPast
    private var lastAttempt = Date.distantPast
    private var fetch: Task<Void, Never>?

    private init() {
        if let data = UserDefaults.standard.data(forKey: cacheKey), data.count < 100_000,
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
           WeeklyScheduleParser.valid(snapshot.meetings) {
            meetings = snapshot.meetings
            lastSuccess = snapshot.date
        }
    }

    func upcoming(after date: Date = Date()) -> [(meeting: WeeklyMeeting, date: Date)] {
        meetings.map { (meeting: $0, date: $0.nextOccurrence(after: date)) }.sorted { $0.date < $1.date }
    }

    func refreshIfNeeded(force: Bool = false) async {
        if let fetch { await fetch.value; return }
        let now = Date()
        if !force, (0..<21_600).contains(now.timeIntervalSince(lastSuccess)) || (0..<60).contains(now.timeIntervalSince(lastAttempt)) { return }
        lastAttempt = now
        // The request is shared across tabs and continues when the initiating view disappears.
        let work = Task {
            defer { fetch = nil }
            guard let latest = try? await Self.fetchMeetings() else { return }
            let snapshot = Snapshot(date: Date(), meetings: latest)
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            UserDefaults.standard.set(data, forKey: cacheKey)
            lastSuccess = snapshot.date
            meetings = latest
        }
        fetch = work
        await work.value
    }

    private nonisolated static func fetchMeetings() async throws -> [WeeklyMeeting] {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 12
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        let session = URLSession(configuration: configuration, delegate: CenterOrigin(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: CenterOrigin.page, timeoutInterval: 8)
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, CenterOrigin.isCenter(http.url),
              http.mimeType == "text/html", http.expectedContentLength <= 262_144 else { throw URLError(.badServerResponse) }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 262_144 else { throw URLError(.dataLengthExceedsMaximum) }
            data.append(byte)
        }
        guard let html = String(data: data, encoding: .utf8), let meetings = WeeklyScheduleParser.parse(html)
        else { throw URLError(.cannotParseResponse) }
        return meetings
    }
}
