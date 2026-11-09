import MapKit
import SwiftUI

private let directoryWash = Color(red: 236/255, green: 235/255, blue: 223/255)

private struct DirectoryPage: Identifiable {
    let name: String
    let path: String
    let keywords: String
    var id: String { path }

    init(_ name: String, _ path: String, _ keywords: String = "") {
        self.name = name
        self.path = path
        self.keywords = keywords
    }
}

private struct DirectoryGroup: Identifiable {
    let title: String
    let symbol: String
    let subtitle: String
    let pages: [DirectoryPage]
    var id: String { title }

    static let groups = [
        DirectoryGroup(title: "Services", symbol: "hand.raised", subtitle: "Marriage, family care, hall rental", pages: [
            .init("Services overview", "/#services", "care services at the Center"),
            .init("Marriage & Nikah", "/marriage/", "wedding premarital ceremony certificate"),
            .init("Divorce guidance", "/divorce/", "marriage mediation separation"),
            .init("Funeral & Janazah", "/funeral/", "burial death rites funeral guidance"),
            .init("Consultation", "/consultation/", "scholar appointment guidance experts counseling"),
            .init("Hall & event rental", "/rent-a-hall/", "reserve book venue Ghadeer Hall Small Hall"),
            .init("Community membership", "/membership/", "member join application"),
            .init("Request a service", "/service-request/", "application inquiry form")
        ]),
        DirectoryGroup(title: "Educational partners", symbol: "book.pages", subtitle: "Schools, seminary and workshops", pages: [
            .init("Learning opportunities", "/#education", "educational partners overview education"),
            .init("Guide Academy", "/guide-academy/", "school children pre-k kindergarten high school"),
            .init("Saturday Islamic School", "/saturday-school/", "children youth weekend classes"),
            .init("Imam Sadiq Seminary", "/imam-sadiq-seminary/", "scholars fiqh Quran adult studies"),
            .init("After school", "/after-school/", "afterschool homework Qur’an character building"),
            .init("Workshops", "/workshops/", "youth classes learning")
        ]),
        DirectoryGroup(title: "Programs", symbol: "calendar", subtitle: "Weekly gatherings and special events", pages: [
            .init("Weekly programs", "/events/", "prayer dua tawassul kumayl jummah friday Quran circle schedule"),
            .init("Event calendar", "/calendar/", "dates schedule calendar"),
            .init("Muharram 2026", "/muharram-2026/", "majlis ashura"),
            .init("Ramadan 2026", "/ramadan-2026/", "iftar fasting"),
            .init("Shahadat & Wiladat 2026", "/shahadat-wiladat-2026/", "majlis commemorations holy days"),
            .init("Live stream", "/live-stream/", "watch livestream broadcast video lectures"),
            .init("Sport activities", "/sport-activities/", "sports athletics youth"),
            .init("Sponsorship", "/sponsorship/", "sponsor events partners"),
            .init("Archive", "/archive/", "programs past events"),
            .init("Gallery", "/gallery/", "photos images videos media shorts")
        ]),
        DirectoryGroup(title: "Resources", symbol: "books.vertical", subtitle: "Library, directories and support", pages: [
            .init("Business directory", "/business-directory/", "businesses listings local companies"),
            .init("Job search", "/job-search/", "jobs employment hiring careers"),
            .init("Shia organizations", "/shia-organizations/", "organizations centres mosques"),
            .init("Revert support", "/revert-support/", "new muslim convert conversion"),
            .init("Online library", "/online-library/", "books reading")
        ]),
        DirectoryGroup(title: "Community", symbol: "person.2", subtitle: "Take part and stay connected", pages: [
            .init("Visit IAC", "/contact/", "contact us email directions maps address phone call parking access"),
            .init("Get involved", "/staff/#volunteer", "staff volunteers volunteer application"),
            .init("Donate", "/donate/", "giving donations support PayPal khums zakat sadaqa Zelle"),
            .init("Prayer times", "/prayer-times/", "salah salat namaz fajr sunrise dhuhr asr maghrib isha"),
            .init("Hijri calendar", "/hijri-calendar/", "islamic lunar dates"),
            .init("IAC mobile app", "/mobile-app/", "app store iPhone Android Google Play reminders"),
            .init("Weekly newsletter", "/#newsletter", "email signup join subscribe announcements")
        ]),
        DirectoryGroup(title: "About us", symbol: "building.columns", subtitle: "The Center, our scholars and staff", pages: [
            .init("About Imam Ali Center", "/about/", "about us mission history IAC community"),
            .init("Staff & volunteers", "/staff/", "get involved team people"),
            .init("Our scholars", "/our-scholars/", "sheikh imam teachers leadership"),
            .init("Privacy policy", "https://jaafarsoccer12.github.io/imam-ali-center-ios/privacy.html", "privacy data retention deletion")
        ])
    ]
}

private struct DirectoryEyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.subheadline.weight(.bold)).tracking(0.65)
            .fixedSize(horizontal: false, vertical: true).foregroundStyle(CenterInk.rust)
    }
}

private struct DirectoryRule: View {
    var body: some View { Rectangle().fill(CenterInk.line).frame(height: 1).accessibilityHidden(true) }
}

private struct DirectoryHeading: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let label: String
    let title: String
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 45
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if !typeSize.isAccessibilitySize { DirectoryEyebrow(text: label) }
            Text(title).font(.system(size: titleSize, weight: .medium, design: .serif))
                .tracking(-1).foregroundStyle(CenterInk.pine).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The native input occupies the entire search box, including its vertical padding.
/// UIKit can therefore hit-test and describe the same rectangle shown on screen.
private struct DirectorySearchInput: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let prompt: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.font = UIFont.preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.textColor = UIColor(CenterInk.pine)
        field.tintColor = UIColor(CenterInk.pine)
        field.returnKeyType = .search
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.accessibilityLabel = "Search the directory"
        field.accessibilityHint = "Find a page by its name or a keyword, such as Nikah."

        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        icon.tintColor = UIColor(CenterInk.pine)
        icon.contentMode = .center
        icon.frame = CGRect(x: 0, y: 0, width: 43, height: 40)
        icon.isAccessibilityElement = false
        field.leftView = icon
        field.leftViewMode = .always
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.input = self
        if field.text != text { field.text = text }
        if field.placeholder != prompt {
            field.attributedPlaceholder = NSAttributedString(string: prompt,
                attributes: [.foregroundColor: UIColor(CenterInk.muted)])
        }
        if isFocused && !field.isFirstResponder && field.window != nil { field.becomeFirstResponder() }
        if !isFocused && field.isFirstResponder { field.resignFirstResponder() }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView field: UITextField, context: Context) -> CGSize? {
        let height = max(56, ceil(field.font?.lineHeight ?? 22) + 20)
        return CGSize(width: proposal.width ?? field.intrinsicContentSize.width,
                      height: max(height, proposal.height ?? height))
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var input: DirectorySearchInput
        init(_ input: DirectorySearchInput) { self.input = input }
        @objc func changed(_ field: UITextField) { input.text = field.text ?? "" }
        func textFieldDidBeginEditing(_ field: UITextField) { if !input.isFocused { input.isFocused = true } }
        func textFieldDidEndEditing(_ field: UITextField) { if input.isFocused { input.isFocused = false } }
        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            field.resignFirstResponder()
            return false
        }
    }
}

struct ExploreScreen: View {
    let open: (URL) -> Void
    @State private var search = ""
    @State private var expanded: Set<String> = []
    @State private var searchFocused = false
    @ScaledMetric(relativeTo: .body) private var searchLineHeight: CGFloat = 22
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize

    private var words: [String] {
        search.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private func matches(in group: DirectoryGroup) -> [DirectoryPage] {
        group.pages.filter { page in
            let searchable = [group.title, page.name, page.keywords].joined(separator: " ")
            return words.allSatisfy { searchable.localizedStandardContains($0) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DirectoryHeading(label: "Center directory", title: "Explore IAC.")
                searchBox.padding(.top, 20).padding(.bottom, 22)
                if words.isEmpty {
                    ForEach(DirectoryGroup.groups) { group in
                        DirectoryRule()
                        groupButton(group)
                        if expanded.contains(group.id) { destinations(group.pages, inset: true) }
                    }
                    DirectoryRule()
                } else {
                    let results = DirectoryGroup.groups.compactMap { group -> (DirectoryGroup, [DirectoryPage])? in
                        let pages = matches(in: group)
                        return pages.isEmpty ? nil : (group, pages)
                    }
                    if results.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No matching pages").font(.title3.weight(.semibold))
                            Text("Try a program, service or school name.").font(.body).foregroundStyle(CenterInk.muted)
                            Button { search = ""; searchFocused = true } label: {
                                Text("Clear search").font(.body.weight(.semibold)).padding(.horizontal, 16)
                                    .frame(minHeight: 50).background(directoryWash, in: RoundedRectangle(cornerRadius: 9))
                            }.buttonStyle(.plain)
                        }.padding(.vertical, 16)
                    } else {
                        let count = results.reduce(0) { $0 + $1.1.count }
                        Text(count == 1 ? "1 matching page" : "\(count) matching pages")
                            .font(.body.weight(.semibold)).foregroundStyle(CenterInk.pine)
                            .accessibilityAddTraits(.isHeader).padding(.bottom, 5)
                        ForEach(results, id: \.0.id) { group, pages in
                            DirectoryEyebrow(text: group.title).padding(.top, 12).padding(.bottom, 8)
                                .accessibilityAddTraits(.isHeader)
                            destinations(pages, inset: false)
                        }
                    }
                }
            }
            .padding(.horizontal, textSize.isAccessibilitySize ? 16 : 20).padding(.top, 22).padding(.bottom, 32)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .foregroundStyle(CenterInk.pine)
        .background(CenterInk.paper)
    }

    private var searchBox: some View {
        HStack(spacing: 0) {
            DirectorySearchInput(text: $search, isFocused: $searchFocused,
                                 prompt: textSize.isAccessibilitySize ? "Search" : "Search the directory")
                .frame(maxWidth: .infinity)
                .frame(height: max(56, searchLineHeight + 20))
            if !search.isEmpty {
                Button { search = ""; searchFocused = true } label: {
                    Image(systemName: "xmark.circle.fill").font(.title3)
                        .foregroundStyle(CenterInk.pine).frame(minWidth: 48, minHeight: 52)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("Clear search")
            }
        }
        .padding(.trailing, search.isEmpty ? 0 : 2).frame(minHeight: 56)
        .background(directoryWash, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(CenterInk.pine.opacity(searchFocused ? 1 : 0.6),
                                                                lineWidth: searchFocused ? 2 : 1))
        .accessibilityElement(children: .contain)
    }

    private func groupButton(_ group: DirectoryGroup) -> some View {
        let isExpanded = expanded.contains(group.id)
        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                if isExpanded { expanded.remove(group.id) } else { expanded.insert(group.id) }
            }
        } label: {
            HStack(spacing: 12) {
                if !textSize.isAccessibilitySize {
                    Image(systemName: group.symbol).font(.title3.weight(.medium))
                        .frame(width: 45, height: 46).foregroundStyle(CenterInk.pine)
                        .background(directoryWash, in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.title).font(.system(.title3, design: .serif).weight(.semibold))
                    Text(group.subtitle).font(.subheadline).foregroundStyle(CenterInk.muted).lineSpacing(2)
                }
                .fixedSize(horizontal: false, vertical: true).layoutPriority(1)
                Spacer(minLength: 4)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.body.weight(.semibold)).foregroundStyle(CenterInk.pine).accessibilityHidden(true)
            }
            .padding(.vertical, 16).frame(minHeight: 69).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel(group.title)
        .accessibilityValue("\(isExpanded ? "Expanded" : "Collapsed"), \(group.pages.count) pages")
        .accessibilityHint(isExpanded ? "Hide these pages" : "Show these pages")
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("explore-group-\(group.id)")
    }

    private func destinations(_ pages: [DirectoryPage], inset: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(pages) { page in
                DirectoryRule()
                Button {
                    searchFocused = false
                    open(centerURL(page.path))
                } label: {
                    HStack {
                        Text(page.name).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Image(systemName: "chevron.right").font(.subheadline.weight(.semibold))
                            .foregroundStyle(CenterInk.muted).accessibilityHidden(true)
                    }
                    .padding(.vertical, 11).frame(minHeight: 54).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }.padding(.leading, inset && !textSize.isAccessibilitySize ? 14 : 0)
    }
}

struct VisitScreen: View {
    let open: (URL) -> Void
    @Environment(\.openURL) private var external
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var unavailableMessage: String?
    private let center = CLLocationCoordinate2D(latitude: 38.74365, longitude: -77.19060)
    private let address = "7900 Backlick Rd\nSpringfield, VA 22150"
    private let mapURL = URL(string: "https://maps.google.com/?q=7900+Backlick+Rd,+Springfield,+VA+22150")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DirectoryHeading(label: "Springfield, Virginia", title: "Visit the Center.")
                Text("Come by for prayer, a program, or a conversation.")
                    .font(.body).foregroundStyle(CenterInk.muted).fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10).padding(.bottom, 20)
                locationCard
                DirectoryEyebrow(text: "Contact the Center").padding(.top, 26).padding(.bottom, 12)
                    .accessibilityAddTraits(.isHeader)
                directContact("Call the Center", value: "(571) 444-3578", symbol: "phone.fill") {
                    launch("tel:+15714443578", fallback: "Call the Center at (571) 444-3578.")
                }
                directContact("Email the Center", value: "iacdmv@gmail.com", symbol: "envelope.fill") {
                    launch("mailto:iacdmv@gmail.com", fallback: "Email the Center at iacdmv@gmail.com.")
                }.padding(.top, 9)
                Text("For parking, accessibility, or a program schedule check, please call before your visit.")
                    .font(.body).foregroundStyle(CenterInk.muted).lineSpacing(3)
                    .padding(.top, 12)
                DirectoryEyebrow(text: "Get in touch").padding(.top, 28).padding(.bottom, 10)
                    .accessibilityAddTraits(.isHeader)
                DirectoryRule()
                visitRow("Send an inquiry", value: "Ask about services, events or visiting", symbol: "text.bubble") {
                    open(centerURL("/contact/#contact-form"))
                }
                visitRow("Weekly newsletter", value: "Program updates and community news", symbol: "newspaper") {
                    open(centerURL("/#newsletter"))
                }
                visitRow("Donate", value: "Support the Center’s work", symbol: "heart") {
                    open(centerURL("/donate/"))
                }
                visitRow("View programs", value: "Weekly and seasonal gatherings", symbol: "calendar") {
                    open(centerURL("/events/"))
                }
                socialLinks
                Text("Imam Ali Center is a nonprofit charitable organization established by Imam Shirazi World Foundation, a 501(c)(3) organization.")
                    .font(.subheadline).lineSpacing(2).foregroundStyle(CenterInk.muted).padding(.top, 22)
            }
            .padding(.horizontal, textSize.isAccessibilitySize ? 16 : 20).padding(.top, 22).padding(.bottom, 32)
            .frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
        .foregroundStyle(CenterInk.pine).background(CenterInk.paper)
        .alert("Contact Imam Ali Center", isPresented: Binding(get: { unavailableMessage != nil }, set: { if !$0 { unavailableMessage = nil } })) {
            Button("Copy", action: {
                if unavailableMessage?.contains("@") == true { UIPasteboard.general.string = "iacdmv@gmail.com" }
                else { UIPasteboard.general.string = "(571) 444-3578" }
                unavailableMessage = nil
            })
            Button("Close", role: .cancel) { unavailableMessage = nil }
        } message: { Text(unavailableMessage ?? "") }
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Map(initialPosition: .region(MKCoordinateRegion(center: center, latitudinalMeters: 1400, longitudinalMeters: 1400)), interactionModes: []) {
                Marker("Imam Ali Center", coordinate: center).tint(CenterInk.rust)
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .automatic, pointsOfInterest: .excludingAll))
            .frame(height: 220).accessibilityLabel("Map showing Imam Ali Center in Springfield, Virginia")
            VStack(alignment: .leading, spacing: 14) {
                Text(address).font(.system(.title2, design: .serif).weight(.semibold)).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                Link(destination: mapURL) {
                    Label("Get directions", systemImage: "location.fill")
                        .font(.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12).padding(.vertical, 9).frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(.white).background(CenterInk.pine, in: RoundedRectangle(cornerRadius: 9))
                        .contentShape(Rectangle())
                }.accessibilityHint("Opens directions to 7900 Backlick Road in Maps.")
            }.padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(directoryWash)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(CenterInk.line, lineWidth: 0.7))
    }

    private func directContact(_ title: String, value: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if !textSize.isAccessibilitySize {
                    Image(systemName: symbol).font(.title3).foregroundStyle(CenterInk.pine)
                        .frame(width: 36).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.body.weight(.semibold))
                    Text(value).font(.body).foregroundStyle(CenterInk.pine)
                }
                .fixedSize(horizontal: false, vertical: true).layoutPriority(1)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.body.weight(.medium)).accessibilityHidden(true)
            }
            .padding(.horizontal, 14).padding(.vertical, 13).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(directoryWash, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(CenterInk.pine.opacity(0.42), lineWidth: 1))
            .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityElement(children: .combine)
    }

    private func visitRow(_ title: String, value: String, symbol: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 14) {
                    if !textSize.isAccessibilitySize {
                        Image(systemName: symbol).font(.title3).frame(width: 25).foregroundStyle(CenterInk.rust).accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.body.weight(.semibold))
                        Text(value).font(.body).foregroundStyle(CenterInk.muted)
                    }.fixedSize(horizontal: false, vertical: true).layoutPriority(1)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.right").font(.subheadline.weight(.medium)).foregroundStyle(CenterInk.muted).accessibilityHidden(true)
                }.padding(.vertical, 13).frame(minHeight: 58).contentShape(Rectangle())
            }.buttonStyle(.plain)
            DirectoryRule()
        }
    }

    private var socialLinks: some View {
        let links: [(String, String)] = [
            ("YouTube", "https://www.youtube.com/@ImamAliCenterVA"),
            ("Instagram", "https://www.instagram.com/imamalicenterva/"),
            ("Facebook", "https://facebook.com/imamalicenterva/"),
            ("X", "https://twitter.com/imamalicenterva"),
            ("Telegram", "https://t.me/ImamAliCenterVA"),
            ("WhatsApp", "https://chat.whatsapp.com/IoCfRhJE6nJGsMWpXzqhkg")
        ]
        return VStack(alignment: .leading, spacing: 9) {
            DirectoryEyebrow(text: "Follow IAC").accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: textSize.isAccessibilitySize ? [GridItem(.flexible())] :
                        [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                ForEach(links, id: \.0) { label, url in
                    Link(destination: URL(string: url)!) {
                        HStack {
                            Text(label).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 2)
                            Image(systemName: "arrow.up.right").font(.subheadline.weight(.medium)).accessibilityHidden(true)
                        }.padding(.horizontal, 12).padding(.vertical, 8).frame(minHeight: 52)
                        .background(directoryWash, in: RoundedRectangle(cornerRadius: 7))
                    }
                }
            }
        }.padding(.top, 28)
    }

    private func launch(_ url: String, fallback: String) {
        external(URL(string: url)!) { accepted in
            if !accepted { unavailableMessage = fallback }
        }
    }
}
