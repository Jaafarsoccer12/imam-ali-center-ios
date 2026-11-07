import SwiftUI
import EventKit
import EventKitUI

private enum AlmanacStyle {
    static let paper = Color(red: 248/255, green: 246/255, blue: 240/255)
    static let pine = Color(red: 17/255, green: 63/255, blue: 56/255)
    static let rust = Color(red: 161/255, green: 70/255, blue: 43/255)
    static let gold = Color(red: 151/255, green: 106/255, blue: 44/255)
    static let muted = Color(red: 82/255, green: 95/255, blue: 85/255)
    static let hairline = pine.opacity(0.19)
    static func url(_ path: String) -> URL { URL(string: "https://imamalicenter.org" + path)! }
}

private struct AlmanacEyebrow: View {
    let title: String
    var color: Color = AlmanacStyle.rust
    var body: some View {
        Text(title).font(.headline).foregroundStyle(color).fixedSize(horizontal: false, vertical: true)
    }
}

private struct AlmanacRule: View {
    var body: some View { Rectangle().fill(AlmanacStyle.hairline).frame(height: 0.75).accessibilityHidden(true) }
}

private struct AlmanacLink: View {
    let title: String
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: symbol).font(.system(size: 18)).frame(width: 24).foregroundStyle(AlmanacStyle.rust)
                Text(title).font(.body.weight(.medium)).multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).accessibilityHidden(true)
            }
            .padding(.vertical, 8).frame(minHeight: 56).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(AlmanacStyle.pine)
        AlmanacRule()
    }
}

/// The system editor lets the visitor pick a calendar, review recurrence, or cancel before saving.
struct MeetingCalendarEditor: UIViewControllerRepresentable {
    let meeting: WeeklyMeeting
    let done: () -> Void

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let store = EKEventStore()
        let completion: () -> Void
        init(completion: @escaping () -> Void) { self.completion = completion }
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            completion()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(completion: done) }
    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = context.coordinator.store
        let event = EKEvent(eventStore: store)
        let start = meeting.nextOccurrence(after: Date())
        event.title = meeting.name
        event.startDate = start
        event.endDate = start
        event.timeZone = SpringfieldClock.zone
        event.location = meeting.location == "Imam Ali Center" ? "Imam Ali Center, 7900 Backlick Rd, Springfield, VA 22150" : meeting.location
        event.notes = meeting.speaker + ". Check the IAC events page for schedule updates."
        event.url = AlmanacStyle.url("/events/")
        event.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil))
        let editor = EKEventEditViewController()
        editor.eventStore = store
        editor.event = event
        editor.editViewDelegate = context.coordinator
        return editor
    }
    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}
}

struct ProgramsScreen: View {
    let open: (URL) -> Void
    @ObservedObject private var schedule = WeeklyScheduleStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var seasonal = false
    @State private var editing: WeeklyMeeting?
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 45

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Programs").font(.system(size: titleSize, weight: .regular, design: .serif))
                    .tracking(-1.1).accessibilityAddTraits(.isHeader)
                let tabLayout = typeSize >= .xxLarge ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
                tabLayout {
                    programTab("Weekly", accessibleTitle: "Weekly schedule", selected: !seasonal) { seasonal = false }
                    programTab("Seasonal", accessibleTitle: "Seasonal programs", selected: seasonal) { seasonal = true }
                }
                .padding(5)
                .background(AlmanacStyle.pine.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
                .padding(.top, 16).padding(.bottom, 13)

                if seasonal {
                    seasonalContent
                } else {
                    Text("Times are local to Springfield, Virginia.")
                        .font(.body).foregroundStyle(AlmanacStyle.muted).padding(.vertical, 5)
                    ForEach(schedule.meetings) { meeting in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(meeting.weekdayLabel + " · " + meeting.timeLabel)
                                .font(.headline).foregroundStyle(AlmanacStyle.rust)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(meeting.name).font(.system(.title, design: .serif, weight: .medium))
                                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                            Text(meeting.speaker).font(.body)
                            Text(meeting.category).font(.body).foregroundStyle(AlmanacStyle.muted)
                            if meeting.location != "Imam Ali Center" {
                                Label(meeting.location, systemImage: "mappin").font(.body).foregroundStyle(AlmanacStyle.muted)
                            }
                            Button { editing = meeting } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar.badge.plus").accessibilityHidden(true)
                                    Text("Add to calendar").fixedSize(horizontal: false, vertical: true)
                                }
                                .font(.body.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 8)
                                .frame(minHeight: 50).background(AlmanacStyle.pine.opacity(0.085), in: RoundedRectangle(cornerRadius: 10))
                                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(AlmanacStyle.pine.opacity(0.27), lineWidth: 1) }
                            }
                            .buttonStyle(.plain).accessibilityLabel("Add " + meeting.name + " to calendar")
                            .padding(.top, 5)
                        }.padding(.vertical, 18).frame(maxWidth: .infinity, alignment: .leading)
                        AlmanacRule()
                    }
                    Text((schedule.meetings.allSatisfy { $0.location == "Imam Ali Center" } ? "Weekly gatherings meet at Imam Ali Center. " : "") + "Check the calendar before visiting.")
                        .font(.body).foregroundStyle(AlmanacStyle.muted).padding(.vertical, 16)
                    AlmanacLink(title: "Program calendar", symbol: "calendar") { open(AlmanacStyle.url("/calendar/")) }
                    AlmanacLink(title: "Contact and directions", symbol: "mappin.and.ellipse") { open(AlmanacStyle.url("/contact/")) }
                }
                AlmanacEyebrow(title: "More programs").padding(.top, 28).padding(.bottom, 12)
                AlmanacRule()
                ForEach(programLinks, id: \.0) { item in
                    AlmanacLink(title: item.0, symbol: item.1) { open(AlmanacStyle.url(item.2)) }
                }
            }
            .frame(maxWidth: 640, alignment: .leading).padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(AlmanacStyle.pine).background(AlmanacStyle.paper).tint(AlmanacStyle.pine)
        .task(id: scenePhase) { if scenePhase == .active { await schedule.refreshIfNeeded() } }
        .refreshable { await schedule.refreshIfNeeded(force: true) }
        .sheet(item: $editing) { meeting in
            MeetingCalendarEditor(meeting: meeting) { editing = nil }.ignoresSafeArea()
        }
    }

    private func programTab(_ text: String, accessibleTitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(.body.weight(.semibold))
                .foregroundStyle(selected ? .white : AlmanacStyle.pine)
                .padding(.horizontal, 8).padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(selected ? AlmanacStyle.pine : AlmanacStyle.paper, in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(AlmanacStyle.pine.opacity(selected ? 0 : 0.3), lineWidth: 1) }
        }
        .buttonStyle(.plain).accessibilityLabel(accessibleTitle).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private let programLinks = [
        ("Live stream", "play.rectangle", "/live-stream/"), ("Sport activities", "figure.run", "/sport-activities/"),
        ("Sponsorship", "heart", "/sponsorship/"), ("Archive", "archivebox", "/archive/"),
        ("Gallery", "photo.on.rectangle.angled", "/gallery/")
    ]

    private var seasonalContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            seasonRow("Majlis & remembrance", "Shahadat & Wiladat gatherings", "Commemorations and celebrations centered on the Ahlulbayt (a.s.).", "/shahadat-wiladat-2026/")
            seasonRow("Women’s community", "Arabic Majlis for Ladies", "A space for reflection, learning, and gathering in community.", "/staff/")
            seasonRow("Community gatherings", "Workshops & seasonal programs", "From Ramadan and Muharram to workshops, sports, and service.", "/workshops/")
            Text("See the IAC calendar for dates and registration.")
                .font(.body).foregroundStyle(AlmanacStyle.muted).padding(.vertical, 18)
            AlmanacLink(title: "Muharram 2026", symbol: "moon.stars", action: { open(AlmanacStyle.url("/muharram-2026/")) })
            AlmanacLink(title: "Ramadan 2026", symbol: "moon", action: { open(AlmanacStyle.url("/ramadan-2026/")) })
            AlmanacLink(title: "Program calendar", symbol: "calendar", action: { open(AlmanacStyle.url("/calendar/")) })
        }
    }

    private func seasonRow(_ type: String, _ title: String, _ summary: String, _ path: String) -> some View {
        Button { open(AlmanacStyle.url(path)) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    AlmanacEyebrow(title: type)
                    Text(title).font(.system(.title2, design: .serif)).multilineTextAlignment(.leading)
                    Text(summary).font(.body).foregroundStyle(AlmanacStyle.muted).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
            }.padding(.vertical, 18).contentShape(Rectangle())
        }.buttonStyle(.plain)
        .overlay(alignment: .bottom) { AlmanacRule() }
    }
}

@MainActor
private final class PrayerAlmanac: ObservableObject {
    static let shared = PrayerAlmanac()

    struct Day {
        let date: Date
        let moments: [PrayerMoment]
        let tomorrowFajr: PrayerMoment
        let fromProvider: Bool

        init(date: Date, minutes: [Int]? = nil) {
            self.date = date
            fromProvider = minutes != nil
            moments = SpringfieldPrayers.assemble(minutes ?? SpringfieldPrayers.localMinutes(on: date), on: date)
            let tomorrow = SpringfieldClock.calendar.date(byAdding: .day, value: 1, to: date)!
            tomorrowFajr = SpringfieldPrayers.assemble(SpringfieldPrayers.localMinutes(on: tomorrow), on: tomorrow)[0]
        }

        func next(after now: Date) -> PrayerMoment {
            moments.first { $0.name != "Sunrise" && $0.date > now } ?? tomorrowFajr
        }
    }

    @Published private var day: Day
    private var inFlight: Set<String> = []
    private var lastAttempt: [String: Date] = [:]

    private init() {
        let date = Date()
        let defaults = UserDefaults.standard
        let cached = defaults.string(forKey: "prayerCalendar.day") == SpringfieldClock.apiDay(date)
            ? defaults.array(forKey: "prayerCalendar.minutes") as? [Int] : nil
        let valid = cached?.count == 6 && cached?.allSatisfy { (0..<1440).contains($0) } == true
        day = Day(date: date, minutes: valid ? cached : nil)
    }

    func schedule(on date: Date) -> Day {
        SpringfieldClock.calendar.isDate(date, inSameDayAs: day.date) ? day : Day(date: date)
    }

    func refresh(for date: Date) async {
        let key = SpringfieldClock.apiDay(date)
        if SpringfieldClock.calendar.isDate(date, inSameDayAs: day.date) {
            if day.fromProvider { return }
        } else { day = Day(date: date) }
        guard !inFlight.contains(key), Date().timeIntervalSince(lastAttempt[key] ?? .distantPast) >= 899 else { return }
        inFlight.insert(key)
        lastAttempt = [key: Date()]
        defer { inFlight.remove(key) }
        do {
            let minutes = try await SpringfieldPrayers.liveMinutes(on: date)
            guard SpringfieldClock.apiDay(Date()) == key else { return }
            day = Day(date: date, minutes: minutes)
            UserDefaults.standard.set(minutes, forKey: "prayerCalendar.minutes")
            UserDefaults.standard.set(key, forKey: "prayerCalendar.day")
        } catch {
            // Local timings remain on screen, with their source explicitly identified.
            if Task.isCancelled { lastAttempt.removeValue(forKey: key) }
        }
    }
}

private struct PrayerTimeText: View {
    let date: Date
    var large = false
    var body: some View {
        Text(SpringfieldClock.clock(date))
            .font(.system(large ? .largeTitle : .title, design: .serif, weight: .medium))
            .monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
    }
}

private func nextDateLabel(_ date: Date, now: Date) -> String {
    let today = SpringfieldClock.calendar.isDate(date, inSameDayAs: now)
    let day = date.formatted(Date.FormatStyle(locale: Locale(identifier: "en_US"), calendar: SpringfieldClock.calendar,
                                               timeZone: SpringfieldClock.zone).month(.abbreviated).day())
    return (today ? "Today, " : "Tomorrow, ") + day
}

struct HomePrayerCard: View {
    let open: () -> Void
    @ObservedObject private var almanac = PrayerAlmanac.shared
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        TimelineView(.everyMinute) { context in
            let day = almanac.schedule(on: context.date)
            let next = day.next(after: context.date)
            let date = nextDateLabel(next.date, now: context.date)
            let spoken = ["Next prayer", next.name, date, SpringfieldClock.clock(next.date)].joined(separator: ", ")
            Button(action: open) { card(next, date: date) }
            .buttonStyle(.plain).foregroundStyle(AlmanacStyle.pine)
            .accessibilityLabel(spoken)
            .accessibilityHint("Shows all prayer times in Springfield.")
            .task(id: Int(context.date.timeIntervalSince1970) / 900) { await almanac.refresh(for: context.date) }
        }
    }

    private var prayerLayout: AnyLayout {
        if typeSize >= .xxLarge { return AnyLayout(VStackLayout(alignment: .leading, spacing: 1)) }
        return AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
    }

    private func card(_ next: PrayerMoment, date: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: "sun.horizon").font(.title3).foregroundStyle(AlmanacStyle.gold)
                Text("Next prayer").font(.headline)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.body.weight(.semibold)).accessibilityHidden(true)
            }
            let layout = prayerLayout
            layout {
                Text(next.name).font(.system(.title, design: .serif, weight: .medium))
                if typeSize < .xxLarge { Spacer(minLength: 0) }
                PrayerTimeText(date: next.date)
            }
            Text(date).font(.body).foregroundStyle(AlmanacStyle.muted)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 244/255, green: 240/255, blue: 228/255)))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(AlmanacStyle.pine.opacity(0.18), lineWidth: 1) }
    }

}

struct PrayerScreen: View {
    let open: (URL) -> Void
    @ObservedObject private var almanac = PrayerAlmanac.shared
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 45
    @State private var methodExpanded = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let day = almanac.schedule(on: now)
            let next = day.next(after: now)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Prayer times").font(.system(size: titleSize, weight: .regular, design: .serif))
                        .tracking(-1.1).accessibilityAddTraits(.isHeader)
                    Text("Springfield, Virginia").font(.body).foregroundStyle(AlmanacStyle.muted).padding(.top, 4)
                    nextPanel(next, now: now).padding(.top, 18).padding(.bottom, 23)
                    Text(SpringfieldClock.dateLabel(now)).font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader)
                    Text("Eastern time").font(.body).foregroundStyle(AlmanacStyle.muted).padding(.top, 4).padding(.bottom, 12)
                    AlmanacRule()
                    ForEach(Array(day.moments.enumerated()), id: \.element.id) { index, item in
                        let layout = typeSize >= .xxxLarge ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
                        layout {
                            HStack(spacing: 12) {
                                Image(systemName: ["moon.stars", "sunrise", "sun.max", "sun.haze", "sunset", "moon"][index])
                                    .font(.body).frame(minWidth: 26).foregroundStyle(AlmanacStyle.gold).accessibilityHidden(true)
                                Text(item.name).font(.system(.title2, design: .serif, weight: item == next ? .semibold : .regular))
                            }
                            if typeSize < .xxxLarge { Spacer(minLength: 0) }
                            Text(SpringfieldClock.clock(item.date)).font(.title3.weight(item == next ? .bold : .medium))
                                .monospacedDigit()
                        }
                        .padding(.vertical, 12).accessibilityElement(children: .combine)
                        AlmanacRule()
                    }
                    Text("For congregation and iqamah times, check with the Center.")
                        .font(.body).foregroundStyle(AlmanacStyle.muted).padding(.top, 14)
                    method(day.fromProvider).padding(.vertical, 12)
                    AlmanacEyebrow(title: "At the Center").padding(.top, 14).padding(.bottom, 12)
                    Text("Friday Prayer").font(.system(.title2, design: .serif))
                    Text("Fridays at 1:10 PM with Sheikh Mustafa Akhound.")
                        .font(.body).foregroundStyle(AlmanacStyle.muted).padding(.top, 5).padding(.bottom, 12)
                    AlmanacRule()
                    AlmanacLink(title: "Weekly gatherings", symbol: "calendar") { open(AlmanacStyle.url("/events/")) }
                    AlmanacLink(title: "Contact the Center", symbol: "telephone") { open(AlmanacStyle.url("/contact/")) }
                    AlmanacLink(title: "Hijri calendar", symbol: "moon.stars") { open(AlmanacStyle.url("/hijri-calendar/")) }
                }
                .frame(maxWidth: 640, alignment: .leading).padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(AlmanacStyle.pine).background(AlmanacStyle.paper).tint(AlmanacStyle.pine)
            .task(id: Int(now.timeIntervalSince1970) / 900) { await almanac.refresh(for: now) }
        }
    }

    private func nextPanel(_ next: PrayerMoment, now: Date) -> some View {
        let layout = typeSize >= .xxLarge ? AnyLayout(VStackLayout(alignment: .leading, spacing: 3))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10))
        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Next prayer").font(.headline)
                Spacer()
                Image(systemName: "sun.horizon").font(.title3.weight(.medium)).accessibilityHidden(true)
            }.foregroundStyle(Color(red: 0.95, green: 0.85, blue: 0.67))
            layout {
                Text(next.name).font(.system(.largeTitle, design: .serif))
                if typeSize < .xxLarge { Spacer(minLength: 0) }
                PrayerTimeText(date: next.date, large: true)
            }
            Text(nextDateLabel(next.date, now: now)).font(.body.weight(.medium))
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 5) {
                    Text("Begins in")
                    Text(timerInterval: now...max(now, next.date), countsDown: true).monospacedDigit().fixedSize()
                }.fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Begins in")
                    Text(timerInterval: now...max(now, next.date), countsDown: true).monospacedDigit()
                }
            }
            .font(.body).foregroundStyle(.white.opacity(0.87))
        }
        .padding(18).foregroundStyle(.white)
        .background(RoundedRectangle(cornerRadius: 13).fill(AlmanacStyle.pine))
    }

    private func method(_ online: Bool) -> some View {
        DisclosureGroup(isExpanded: $methodExpanded) {
            VStack(alignment: .leading, spacing: 0) {
                Text(online ? "AlAdhan provides these astronomical times for Springfield using the Institute of Geophysics, University of Tehran method (method 7)." : "Times are calculated locally for Springfield using the University of Tehran method 7 parameters: Fajr 17.7°, Maghrib 4.5°, and Isha 14°.")
                    .font(.body).foregroundStyle(AlmanacStyle.muted).padding(.vertical, 10)
                methodLink("AlAdhan method data", "https://api.aladhan.com/v1/methods")
                methodLink("University of Tehran Calendar Center", "https://calendar.ut.ac.ir/Fa/")
                methodLink("AlAdhan API details", "https://aladhan.com/prayer-times-api")
            }.frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("How times are calculated", systemImage: "info.circle")
                .font(.body.weight(.semibold)).frame(minHeight: 50)
        }
    }

    private func methodLink(_ title: String, _ destination: String) -> some View {
        Link(destination: URL(string: destination)!) {
            HStack(spacing: 7) {
                Text(title).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Image(systemName: "arrow.up.right").font(.subheadline.weight(.semibold)).accessibilityHidden(true)
            }
            .font(.body.weight(.medium)).padding(.vertical, 6).frame(minHeight: 48).contentShape(Rectangle())
        }
    }
}
