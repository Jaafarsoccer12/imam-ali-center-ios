import SwiftUI
import WebKit
import SafariServices

/// Keeps interactive pages on the Center's HTTPS origin. The app stores only a
/// read-only snapshot; offline forms never accept personal details or payments.
struct DetailReader: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var bodyPointSize: CGFloat = 17
    @StateObject private var reader: CenterReaderState

    init(url: URL) {
        _reader = StateObject(wrappedValue: CenterReaderState(url: url))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button {
                    if reader.canGoBack { reader.goBack() } else { dismiss() }
                } label: {
                    toolbarIcon(reader.canGoBack ? "chevron.backward" : "xmark")
                }
                .accessibilityLabel(reader.canGoBack ? "Back" : "Close")
                VStack(alignment: .leading, spacing: 1) {
                    if dynamicTypeSize.isAccessibilitySize {
                        Text("IAC").font(.headline).accessibilityLabel(reader.title)
                    } else {
                        Text(reader.title).font(.headline).lineLimit(2)
                        Text("imamalicenter.org").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 2)
                Menu {
                    Button("Open in Safari", systemImage: "safari") { reader.openSystem(reader.canonicalURL) }
                    ShareLink(item: reader.canonicalURL)
                    if !reader.offline && reader.hasSavedCopy {
                        Button("Read saved copy", systemImage: "tray.full") { reader.readSavedCopy() }
                    }
                    Button("Reload", systemImage: "arrow.clockwise") { reader.reload() }
                    if reader.canGoBack {
                        Button("Close", systemImage: "xmark") { dismiss() }
                    }
                } label: {
                    toolbarIcon("ellipsis")
                }
                .accessibilityLabel("Page options")
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .foregroundStyle(CenterInk.pine)
            .background(CenterInk.paper)

            Rectangle().fill(CenterInk.line).frame(height: 1)
                .overlay(alignment: .leading) {
                    if reader.loading {
                        ProgressView(value: reader.progress)
                            .tint(CenterInk.rust).accessibilityLabel("Loading page")
                    }
                }

            if reader.offline {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        savedCopyLabel
                        Spacer(minLength: 12)
                        livePageButton
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        savedCopyLabel
                        livePageButton
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 18).padding(.vertical, 3)
                .foregroundStyle(CenterInk.pine).background(CenterInk.gold.opacity(0.32))
            }

            if reader.cannotLoad {
                Spacer()
                Image(systemName: "wifi.exclamationmark").font(.title)
                Text("Page unavailable").font(.title3.bold()).padding(.top, 8)
                Text("Connect to the internet and try again.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Try again") { reader.reload() }.buttonStyle(.bordered).controlSize(.large).padding(.top, 8)
                Spacer()
            } else {
                CenterWebContent(reader: reader)
            }
        }
        .background(CenterInk.paper)
        .onAppear {
            reader.setTextSize(bodyPointSize)
            reader.start()
        }
        .onChange(of: bodyPointSize) { _, newSize in reader.setTextSize(newSize) }
        .sheet(item: $reader.presentation, onDismiss: { reader.cleanupDownload() }) { item in
            switch item.kind {
            case .website:
                CenterExternalWebsite(url: item.url).ignoresSafeArea()
            case .file:
                CenterFileShare(url: item.url)
            }
        }
        .alert("Link unavailable", isPresented: $reader.linkUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device could not open the link.")
        }
    }

    private func toolbarIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 38, height: 38)
            .background(CenterInk.pine.opacity(0.075), in: Circle())
            .frame(width: 52, height: 52).contentShape(Rectangle())
    }

    private var savedCopyLabel: some View {
        Label("Saved copy", systemImage: "tray.full")
            .font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
    }

    private var livePageButton: some View {
        Button { reader.reload() } label: {
            Text("Try live page").font(.subheadline.weight(.semibold))
                .frame(minHeight: 48).contentShape(Rectangle())
        }
    }
}

private struct CenterWebContent: UIViewRepresentable {
    let reader: CenterReaderState
    func makeUIView(context: Context) -> WKWebView { reader.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

private struct CenterExternalWebsite: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(CenterInk.pine)
        return controller
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

private struct CenterFileShare: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct ReaderPresentation: Identifiable {
    enum Kind { case website, file }
    let id = UUID()
    let kind: Kind
    let url: URL
}

private enum CenterPageStore {
    static let scheme = "iac-saved"
    static func isCenter(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" &&
            ["imamalicenter.org", "www.imamalicenter.org"].contains(url.host?.lowercased() ?? "")
    }

    static func canonical(_ url: URL) -> URL? {
        if isCenter(url) { return url }
        guard url.scheme == scheme, url.host == "snapshot",
              var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        parts.scheme = "https"
        parts.host = "imamalicenter.org"
        return parts.url
    }

    static func saved(_ url: URL) -> URL? {
        guard isCenter(url), var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        parts.scheme = scheme
        parts.host = "snapshot"
        guard let savedURL = parts.url, resource(for: savedURL) != nil else { return nil }
        return savedURL
    }

    static func resource(name: String, folder: String = "") -> URL? {
        guard !name.contains("/"), !name.contains(".."), !name.isEmpty else { return nil }
        let directories = ["Content", "Resources/Content"].map { folder.isEmpty ? $0 : $0 + "/" + folder }
        return directories.lazy.compactMap { Bundle.main.url(forResource: name, withExtension: nil, subdirectory: $0) }.first
            ?? Bundle.main.url(forResource: name, withExtension: nil)
    }

    static func resource(for url: URL) -> URL? {
        guard url.scheme == scheme, url.host == "snapshot" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        if parts.count == 2, parts[0] == "assets" {
            return resource(name: parts[1], folder: "assets")
        }
        if let name = parts.first, parts.count == 1, ["site.css", "reader.css"].contains(name) {
            return resource(name: name)
        }
        let slug = parts.isEmpty ? "home" : parts.joined(separator: "--")
        guard slug.range(of: "^[a-z0-9-]+$", options: .regularExpression) != nil else { return nil }
        return resource(name: "page-" + slug + ".html")
    }
}

private final class CenterSavedScheme: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url, let file = CenterPageStore.resource(for: requestURL),
              let data = try? Data(contentsOf: file, options: .mappedIfSafe) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let mime = ["html": "text/html", "css": "text/css", "jpg": "image/jpeg", "jpeg": "image/jpeg",
                    "png": "image/png", "webp": "image/webp"][file.pathExtension.lowercased()] ?? "application/octet-stream"
        urlSchemeTask.didReceive(URLResponse(url: requestURL, mimeType: mime, expectedContentLength: data.count,
                                              textEncodingName: mime.hasPrefix("text/") ? "utf-8" : nil))
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

@MainActor
private final class CenterReaderState: NSObject, ObservableObject, WKNavigationDelegate, WKDownloadDelegate {
    let webView: WKWebView
    @Published var canonicalURL: URL
    @Published var title = "Imam Ali Center"
    @Published var loading = true
    @Published var progress = 0.0
    @Published var canGoBack = false
    @Published var offline = false
    @Published var cannotLoad = false
    @Published var linkUnavailable = false
    @Published var presentation: ReaderPresentation?

    private var observations: [NSKeyValueObservation] = []
    private let readerStyles: String
    private var bodyPointSize: CGFloat?
    private var started = false
    private var privacyReady = false
    private var fileToShare: URL?

    init(url: URL) {
        canonicalURL = url
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.allowsInlineMediaPlayback = true
        configuration.setURLSchemeHandler(CenterSavedScheme(), forURLScheme: CenterPageStore.scheme)
        let styleURL = CenterPageStore.resource(name: "reader.css")
        let css = styleURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        let encodedCSS = try? JSONEncoder().encode(css)
        readerStyles = encodedCSS.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.underPageBackgroundColor = UIColor(CenterInk.paper)
        observations = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, change in
                guard let progress = change.newValue else { return }
                Task { @MainActor in self?.progress = progress }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] _, change in
                guard let canGoBack = change.newValue else { return }
                Task { @MainActor in self?.canGoBack = canGoBack }
            },
            webView.observe(\.title, options: [.new]) { [weak self] _, change in
                guard let title = change.newValue ?? nil,
                      let shortTitle = title.components(separatedBy: " | ").first, !shortTitle.isEmpty else { return }
                Task { @MainActor in self?.title = shortTitle }
            }
        ]
    }

    /// Use the same system body size in WebKit as the surrounding SwiftUI views.
    /// Updating the current document keeps the user's place and any entered form values.
    func setTextSize(_ size: CGFloat) {
        guard size.isFinite, size > 0, bodyPointSize != size else { return }
        bodyPointSize = size
        let script = """
        (() => {
          const live = ['imamalicenter.org','www.imamalicenter.org'].includes(location.hostname);
          if (!live && location.protocol !== 'iac-saved:') return;
          const apply = () => {
            const root = document.documentElement;
            if (!root) return;
            root.style.setProperty('--reader-body', '\(size)px');
            root.toggleAttribute('data-large-type', \(size >= 22 ? "true" : "false"));
            if (live) {
              const style = document.getElementById('iac-mobile-reader') || document.createElement('style');
              style.id = 'iac-mobile-reader';
              style.textContent = \(readerStyles);
              (document.head || root).appendChild(style);
            }
          };
          apply();
          if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', apply, {once:true});
        })();
        """
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        if started, webView.url != nil { webView.evaluateJavaScript(script, completionHandler: nil) }
    }

    func start() {
        guard !started else { return }
        started = true
        let rules = #"[{"trigger":{"url-filter":"^https?://([^/]+[.])?(googletagmanager[.]com|google-analytics[.]com|analytics[.]google[.]com|cloudflareinsights[.]com|doubleclick[.]net|googleadservices[.]com|googlesyndication[.]com)/"},"action":{"type":"block"}}]"#
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "IACReaderPrivacy-v1", encodedContentRuleList: rules) { [weak self] list, _ in
            Task { @MainActor in
                guard let self else { return }
                guard let list else {
                    if self.hasSavedCopy { self.readSavedCopy() }
                    else { self.loading = false; self.cannotLoad = true }
                    return
                }
                self.webView.configuration.userContentController.add(list)
                self.privacyReady = true
                self.reload()
            }
        }
    }

    func reload() {
        guard privacyReady else { return }
        cannotLoad = false
        loading = true
        webView.load(URLRequest(url: canonicalURL, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 12))
    }

    var hasSavedCopy: Bool { CenterPageStore.saved(canonicalURL) != nil }

    func readSavedCopy() {
        guard let saved = CenterPageStore.saved(canonicalURL) else { return }
        cannotLoad = false
        webView.load(URLRequest(url: saved))
    }

    func goBack() { webView.goBack() }

    func openSystem(_ url: URL) {
        UIApplication.shared.open(url, options: [:]) { [weak self] opened in
            if !opened { self?.linkUnavailable = true }
        }
    }

    private func openExternal(_ url: URL) {
        guard let scheme = url.scheme?.lowercased() else { return }
        let host = url.host?.lowercased() ?? ""
        if ["tel", "mailto", "sms", "maps", "itms-apps"].contains(scheme)
            || ["maps.google.com", "maps.apple.com", "apps.apple.com", "play.google.com"].contains(host) {
            openSystem(url)
        } else if ["http", "https"].contains(scheme) {
            presentation = ReaderPresentation(kind: .website, url: url)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        if action.targetFrame?.isMainFrame == false { decisionHandler(.allow); return }
        if url.scheme == "iac-live", url.host == "retry", action.sourceFrame.request.url?.scheme == CenterPageStore.scheme {
            decisionHandler(.cancel)
            var parts = URLComponents(url: canonicalURL, resolvingAgainstBaseURL: false)
            if let fragment = url.fragment { parts?.fragment = fragment }
            if let destination = parts?.url { webView.load(URLRequest(url: destination, timeoutInterval: 12)) }
            return
        }
        if action.shouldPerformDownload {
            let trusted = action.sourceFrame.isMainFrame && webView.url.map { CenterPageStore.isCenter($0) } == true
            decisionHandler(trusted ? .download : .cancel)
            return
        }
        if let canonical = CenterPageStore.canonical(url) {
            if action.targetFrame == nil {
                decisionHandler(.cancel)
                webView.load(action.request)
                return
            }
            canonicalURL = canonical
            decisionHandler(.allow)
        } else if url.absoluteString == "about:blank" {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
            openExternal(url)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void) {
        if response.isForMainFrame, let http = response.response as? HTTPURLResponse,
           http.statusCode >= 400, let failedURL = http.url, let saved = CenterPageStore.saved(failedURL) {
            decisionHandler(.cancel)
            webView.load(URLRequest(url: saved))
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loading = true
        cannotLoad = false
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        offline = webView.url?.scheme == CenterPageStore.scheme
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loading = false }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showSavedPage(after: error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showSavedPage(after: error)
    }

    private func showSavedPage(after error: Error) {
        let failure = error as NSError
        guard failure.code != NSURLErrorCancelled,
              !(failure.domain == "WebKitErrorDomain" && failure.code == 102) else { return }
        let failed = failure.userInfo[NSURLErrorFailingURLErrorKey] as? URL ?? canonicalURL
        if let saved = CenterPageStore.saved(failed) {
            webView.load(URLRequest(url: saved))
        } else {
            cannotLoad = true
            loading = false
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        cannotLoad = true
        loading = false
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String,
                  completionHandler: @escaping @MainActor @Sendable (URL?) -> Void) {
        // The Center's calendar buttons generate local .ics files. Only those are handed to the share sheet.
        let name = URL(fileURLWithPath: suggestedFilename).lastPathComponent
        guard name.lowercased().hasSuffix(".ics"), fileToShare == nil else { completionHandler(nil); return }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + name)
        fileToShare = file
        completionHandler(file)
    }

    func downloadDidFinish(_ download: WKDownload) {
        if let fileToShare { presentation = ReaderPresentation(kind: .file, url: fileToShare) }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        cleanupDownload()
        if (error as NSError).code != NSURLErrorCancelled { linkUnavailable = true }
    }

    func cleanupDownload() {
        if let fileToShare { try? FileManager.default.removeItem(at: fileToShare) }
        fileToShare = nil
    }
}
