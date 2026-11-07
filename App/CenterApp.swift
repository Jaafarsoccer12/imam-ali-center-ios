import SwiftUI
import SafariServices

@main
struct CenterApp: App {
    init() {
        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = UIColor(CenterInk.paper)
        tabBar.shadowColor = UIColor(CenterInk.line)
        let metrics = UIFontMetrics(forTextStyle: .caption1)
        for layout in [tabBar.stackedLayoutAppearance, tabBar.inlineLayoutAppearance, tabBar.compactInlineLayoutAppearance] {
            layout.normal.iconColor = UIColor(CenterInk.muted)
            layout.normal.titleTextAttributes = [
                .foregroundColor: UIColor(CenterInk.muted),
                .font: metrics.scaledFont(for: .systemFont(ofSize: 12, weight: .medium), maximumPointSize: 14)
            ]
            layout.selected.iconColor = UIColor(CenterInk.pine)
            layout.selected.titleTextAttributes = [
                .foregroundColor: UIColor(CenterInk.pine),
                .font: metrics.scaledFont(for: .systemFont(ofSize: 12, weight: .bold), maximumPointSize: 14)
            ]
        }
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar
    }

    var body: some Scene {
        WindowGroup { CenterShell().preferredColorScheme(.light) }
    }
}

enum CenterInk {
    static let paper = Color(red: 248/255, green: 246/255, blue: 240/255)
    static let pine = Color(red: 17/255, green: 63/255, blue: 56/255)
    static let rust = Color(red: 157/255, green: 67/255, blue: 43/255)
    static let muted = Color(red: 84/255, green: 99/255, blue: 90/255)
    static let gold = Color(red: 231/255, green: 198/255, blue: 137/255)
    static let line = Color(red: 213/255, green: 215/255, blue: 202/255)
}

enum CenterTab: String {
    case home = "Home", programs = "Programs", explore = "Explore", visit = "Visit"
}

private struct CenterPage: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
func centerURL(_ path: String) -> URL {
    URL(string: path, relativeTo: URL(string:"https://imamalicenter.org/")!)!.absoluteURL
}
private struct ExternalPage: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(CenterInk.pine)
        return controller
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct CenterShell: View {
    @State private var tab = CenterTab.home
    @State private var detail: CenterPage?
    @State private var external: CenterPage?
    @State private var prayer = false
    @State private var unavailable = false
    @Environment(\.openURL) private var systemOpen
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        TabView(selection: $tab) {
            HomeScreen(open: route, programs: { tab = .programs }, prayer: { prayer = true })
                .tag(CenterTab.home)
                .tabItem { Label("Home", systemImage: "house") }
            ProgramsScreen(open: route).tag(CenterTab.programs)
                .tabItem { Label("Programs", systemImage: "calendar") }
            ExploreScreen(open: route).tag(CenterTab.explore)
                .tabItem { Label("Explore", systemImage: "square.grid.2x2") }
            VisitScreen(open: route).tag(CenterTab.visit)
                .tabItem { Label("Visit", systemImage: "mappin.and.ellipse") }
        }
        .background(CenterInk.paper)
        .tint(CenterInk.pine)
        .sheet(item: $detail) { page in DetailReader(url: page.url).preferredColorScheme(.light) }
        .sheet(item: $external) { page in ExternalPage(url: page.url).ignoresSafeArea() }
        .sheet(isPresented: $prayer) {
            VStack(spacing: 0) {
                HStack {
                    if !typeSize.isAccessibilitySize { Text("Daily prayer").font(.headline) }
                    Spacer()
                    Button { prayer = false } label: {
                        Text("Done").font(.body.weight(.semibold))
                            .padding(.horizontal, 15).frame(minHeight: 48)
                            .background(CenterInk.pine.opacity(0.08), in: Capsule())
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 18).padding(.vertical, 5)
                Divider()
                PrayerScreen { url in
                    prayer = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { route(url) }
                }
            }.foregroundStyle(CenterInk.pine).background(CenterInk.paper)
                .presentationDragIndicator(.visible).padding(.top, 10).presentationBackground(CenterInk.paper)
        }
        .alert("This action isn’t available on this device.", isPresented: $unavailable) { Button("OK") {} }
    }
    private func route(_ url: URL) {
        let host = url.host?.lowercased()
        if host == "imamalicenter.org" || host == "www.imamalicenter.org" {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            switch (path, url.fragment ?? "") {
            case ("prayer-times", ""), ("", "prayer-times"): prayer = true
            case ("", "programs"): tab = .programs
            case ("contact", ""), ("", "contact"): tab = .visit
            case ("", ""), ("", "home"): tab = .home
            default: detail = CenterPage(url: url)
            }
        } else if ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            if host == "maps.apple.com" || host == "maps.google.com" || host == "apps.apple.com" {
                systemOpen(url) { if !$0 { unavailable = true } }
            } else { external = CenterPage(url: url) }
        } else {
            systemOpen(url) { if !$0 { unavailable = true } }
        }
    }
}
