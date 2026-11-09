import SwiftUI

struct HomeScreen: View {
    @ObservedObject private var schedule = WeeklyScheduleStore.shared
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var chosenMeeting: WeeklyMeeting?
    let open: (URL) -> Void
    let programs: () -> Void
    let prayer: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                masthead.padding(.horizontal, 18).padding(.vertical, 12)
                HomePrayerCard(open: prayer).padding(.horizontal, 16)
                CoverStory(open: open).padding(.horizontal, 16).padding(.top, 14)
                week.padding(.horizontal, 20).padding(.top, 24)
                services.padding(.horizontal, 20).padding(.top, 30)
                education.padding(.top, 30)
                wisdom.padding(.horizontal, 20).padding(.top, 28)
                more.padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 28)
            }
            .frame(maxWidth: 700).frame(maxWidth: .infinity)
        }
        .background(CenterInk.paper)
        .task { await schedule.refreshIfNeeded() }
        .sheet(item: $chosenMeeting) { meeting in
            UpcomingGathering(meeting: meeting).presentationDragIndicator(.visible)
        }
    }

    private var masthead: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { identity; Spacer(minLength: 0); giveButton }
            VStack(alignment: .leading, spacing: 12) { identity; giveButton }
        }
    }

    private var identity: some View {
        HStack(spacing: 10) {
            Image("iac-mark").resizable().renderingMode(.template).scaledToFit()
                .frame(width: 40, height: 40).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Imam Ali Center").font(.custom("Georgia", size: 23, relativeTo: .title3))
                    .tracking(-0.7).accessibilityAddTraits(.isHeader)
                if !typeSize.isAccessibilitySize {
                    Text("Springfield, Virginia").font(.subheadline).foregroundStyle(CenterInk.muted)
                }
            }
        }.foregroundStyle(CenterInk.pine)
    }

    private var giveButton: some View {
        Button { open(centerURL("/donate/")) } label: {
            Label("Donate", systemImage: "heart")
                .font(.body.weight(.semibold)).labelStyle(.titleAndIcon)
                .padding(.horizontal, 13).padding(.vertical, 6).frame(minHeight: 48)
                .background(CenterInk.pine.opacity(0.08), in: Capsule())
                .foregroundStyle(CenterInk.pine)
        }.buttonStyle(.plain).accessibilityIdentifier("donate")
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.custom("Georgia", size: 28, relativeTo: .title))
            .tracking(-0.5).foregroundStyle(CenterInk.pine).accessibilityAddTraits(.isHeader)
    }

    private var week: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack { sectionTitle("Coming up"); Spacer(minLength: 8); scheduleButton }
                VStack(alignment: .leading, spacing: 4) { sectionTitle("Coming up"); scheduleButton }
            }.padding(.bottom, 4)
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                let next = Array(schedule.upcoming(after: timeline.date).prefix(2))
                ForEach(next, id: \.meeting.id) { item in
                    Divider()
                    Button { chosenMeeting = item.meeting } label: {
                        HStack(spacing: 14) {
                            if !typeSize.isAccessibilitySize {
                                VStack(spacing: 0) {
                                    Text(datePart(item.date, pattern: "MMM")).font(.subheadline.weight(.semibold))
                                    Text(datePart(item.date, pattern: "d")).font(.title2.weight(.medium))
                                }
                                .foregroundStyle(CenterInk.rust)
                                .padding(5).frame(minWidth: 56, minHeight: 59)
                                .background(Color(red: 0.94, green: 0.91, blue: 0.85), in: RoundedRectangle(cornerRadius: 9))
                                .accessibilityHidden(true)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.meeting.name).font(.headline).foregroundStyle(CenterInk.pine)
                                Text(datePart(item.date, pattern: typeSize.isAccessibilitySize ? "EEEE, MMMM d" : "EEEE") + " · " + item.meeting.timeLabel)
                                    .font(.body).foregroundStyle(CenterInk.muted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.body.weight(.medium)).foregroundStyle(CenterInk.muted).accessibilityHidden(true)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 12).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.meeting.name + ", " + datePart(item.date, pattern: "EEEE, MMMM d") + ", " + item.meeting.timeLabel)
                    .accessibilityHint("Shows gathering details and calendar options.")
                    .accessibilityIdentifier("upcoming-event")
                }
            }
            Divider()
        }
    }

    private var scheduleButton: some View {
        Button(action: programs) {
            Label("Full schedule", systemImage: "calendar").font(.body.weight(.semibold))
                .padding(.horizontal, 10).frame(minHeight: 48).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(CenterInk.pine)
    }

    private let shortcuts = [
        ("calendar", "Programs & events", "/#programs"),
        ("bubble.left.and.bubble.right", "Speak with a scholar", "/consultation/"),
        ("building.columns", "Reserve a hall", "/rent-a-hall/"),
        ("hand.raised", "Funeral guidance", "/funeral/")
    ]

    private var services: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("At the Center")
            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize >= .xxLarge ? 1 : 2)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(shortcuts, id: \.2) { item in
                    Button { open(centerURL(item.2)) } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: item.0).font(.title2).accessibilityHidden(true)
                            Text(item.1).font(.body.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 79, alignment: .leading).padding(13)
                        .background(Color.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 12))
                        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(CenterInk.line) }
                    }.buttonStyle(.plain).foregroundStyle(CenterInk.pine)
                }
            }
            actionRow("All community services", path: "/#services")
        }
    }

    private let schools = [
        ("Guide Academy", "Pre-K through high school", "guide-academy-banner", "/guide-academy/"),
        ("Saturday Islamic School", "Islamic learning for young people", "iac-school-students", "/saturday-school/"),
        ("Imam Sadiq Seminary", "Fiqh and Qur’anic studies", "imam-sadiq-seminary", "/imam-sadiq-seminary/"),
        ("After School Program", "Homework, Qur’an, and character building", "iac-quran-circle", "/after-school/"),
        ("Community Workshops", "Faith in conversation with today’s questions", "iac-youth-discussion", "/workshops/")
    ]

    private var education: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Education").padding(.horizontal, 20)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(schools, id: \.3) { school in
                        Button { open(centerURL(school.3)) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Color.clear.aspectRatio(1.65, contentMode: .fit)
                                    .overlay { Image(school.2).resizable().scaledToFill() }
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .accessibilityHidden(true)
                                Text(school.0).font(.title3.weight(.semibold)).foregroundStyle(CenterInk.pine).padding(.top, 3)
                                Text(school.1).font(.body).foregroundStyle(CenterInk.muted)
                            }
                            .multilineTextAlignment(.leading)
                            .containerRelativeFrame(.horizontal) { width, _ in min(width * 0.84, 380) }
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }.scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            actionRow("All educational partners", path: "/#education").padding(.horizontal, 20)
        }
    }

    private var wisdom: some View {
        let item = HomeEdition.shared.saying
        return Button { if let url = URL(string: item.url) { open(url) } } label: {
            VStack(alignment: .leading, spacing: 12) {
                Label("Daily wisdom", systemImage: "sparkle").font(.headline).foregroundStyle(CenterInk.rust)
                Text("“" + item.text + "”").font(.custom("Georgia-Italic", size: 21, relativeTo: .title3))
                Label(item.label, systemImage: "arrow.up.right").font(.subheadline.weight(.medium))
            }
            .multilineTextAlignment(.leading).foregroundStyle(CenterInk.pine)
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.94, green: 0.92, blue: 0.87), in: RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain)
    }

    private var more: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("Stay connected").padding(.bottom, 10)
            actionRow("Watch lectures and recitations", path: "/watch-listen/")
            actionRow("IAC Shorts", path: "/#media")
            actionRow("Weekly newsletter", path: "/#newsletter")
            actionRow("About the Center", path: "/about/")
            actionRow("Ways to give", path: "/donate/")
            actionRow("Plan your visit", path: "/contact/")
            actionRow("Privacy policy", path: "https://jaafarsoccer12.github.io/imam-ali-center-ios/privacy.html")
        }
    }

    private func actionRow(_ label: String, path: String) -> some View {
        Button { open(centerURL(path)) } label: {
            HStack(spacing: 10) {
                Text(label).font(.body.weight(.medium))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.body).accessibilityHidden(true)
            }
            .padding(.vertical, 8).frame(minHeight: 54).contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(CenterInk.pine)
        .overlay(alignment: .bottom) { Divider() }
    }
}

private func datePart(_ date: Date, pattern: String) -> String {
    let format = DateFormatter()
    format.locale = Locale(identifier: "en_US")
    format.timeZone = SpringfieldClock.zone
    format.dateFormat = pattern
    return format.string(from: date)
}

private struct UpcomingGathering: View {
    let meeting: WeeklyMeeting
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var reviewingCalendar = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Gathering details").font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Text("Done").font(.body.weight(.semibold)).padding(.horizontal, 15)
                        .frame(minHeight: 48).background(CenterInk.pine.opacity(0.08), in: Capsule())
                }
            }.padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 5)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(meeting.name).font(.custom("Georgia", size: 32, relativeTo: .largeTitle)).accessibilityAddTraits(.isHeader)
                    Label(datePart(meeting.nextOccurrence(after: .now), pattern: "EEEE, MMMM d") + " · " + meeting.timeLabel, systemImage: "calendar")
                        .font(.headline)
                    Label(meeting.location, systemImage: "mappin.and.ellipse")
                    Text(meeting.speaker).font(.body)
                    Button { reviewingCalendar = true } label: {
                        Label("Add to calendar", systemImage: "calendar.badge.plus").font(.body.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 9).frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(.white).background(CenterInk.pine, in: RoundedRectangle(cornerRadius: 12))
                    }.padding(.top, 4)
                }.frame(maxWidth: 600, alignment: .leading).padding(20).frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(CenterInk.pine).buttonStyle(.plain).background(CenterInk.paper)
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .sheet(isPresented: $reviewingCalendar) {
            MeetingCalendarEditor(meeting: meeting) { reviewingCalendar = false }.ignoresSafeArea()
        }
    }
}
