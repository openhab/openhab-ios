// Copyright (c) 2010-2026 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Combine
import OpenHABCore
import os.log
import SafariServices
import UIKit
import WebKit

/// A single action button proxied from the MainUI web navbar.
struct WebNavbarItem: Identifiable {
    let id = UUID()
    let label: String
    let jsAction: String
    /// Base64-encoded PNG of the icon rendered from the web navbar element.
    /// Nil if capture failed; fall back to `label` text in that case.
    let iconBase64: String?
    /// True when the JS identified this item as a back-navigation button,
    /// either via the standard F7 `.back` class or the oh-nav-content chevron icon.
    let isBack: Bool

    var iconImage: UIImage? {
        guard let b64 = iconBase64,
              let data = Data(base64Encoded: b64) else { return nil }
        return UIImage(data: data)
    }
}

@MainActor
class OpenHABWebViewModel: ObservableObject {
    // MARK: - Published state

    @Published var isLoading = false
    @Published private(set) var webView: WKWebView

    #if DEBUG
    /// JS probe results keyed by the probe name. Exposed as zero-size accessibility
    /// labels so UI tests can read DOM measurements without native UI.
    @Published private(set) var uiTestReports: [String: String] = [:]
    /// True once a UI test has injected HTML or navbar items — blocks loadWebView
    /// from overriding injected state with real server content.
    private var uiTestContentLocked = false
    #endif

    /// Whether the iOS menu bar (and its hamburger button) should be visible.
    /// Starts true (visible while loading) and is hidden once the openHAB
    /// Main UI signals it has rendered its own native-app exit button via SSE,
    /// or when the page requests fullscreen via JS.
    @Published var showMenuBar = true
    /// True once the Main UI SPA has established its SSE connection.
    /// Used to determine when the native menu bar can be hidden and to show
    /// a connection-status indicator while connecting or offline.
    @Published private(set) var isSSEConnected = false
    /// Navbar items proxied from the MainUI web top bar. Empty until the JS
    /// MutationObserver posts the first `navbarElements` message.
    @Published private(set) var navbarItems: [WebNavbarItem] = []
    /// Title text proxied from the MainUI web navbar. Empty until the JS
    /// proxy posts the first `navbarElements` message.
    @Published private(set) var navbarTitle = ""
    /// True while MainUI has hidden its own navbar (Framework7 `hide-bars-on-scroll`).
    @Published private(set) var isWebNavbarHidden = false
    /// True while an expanded large title is showing the page title instead.
    @Published private(set) var isWebNavbarTitleHidden = false
    /// MainUI's `--f7-navbar-height`, excluding the safe area. 44 on iOS, 56 on Material.
    @Published private(set) var webNavbarHeight: CGFloat = 44
    /// True while the web view holds a tile's URL. Its content outlives the surface that
    /// loaded it, so a sitemap detour does not put the Main UI back.
    @Published private(set) var isShowingTile = false
    /// True once a real page (not the blank placeholder) has finished loading.
    /// Drives the "Connecting…" placeholder shown while a home is first loading.
    @Published private(set) var hasLoadedContent = false

    // MARK: - Internal state (used by Coordinator)

    var acceptsCommands = false
    var commandQueue: [String] = []
    var lastLoadedURL: String?
    /// The connection that produced the page now on screen. Origin alone cannot tell two
    /// connections apart when only the credentials differ.
    private var lastLoadedConfiguration: ConnectionConfiguration?
    /// Callback fired when "exitToApp" is received from JS
    var onExitToApp: (() -> Void)?

    // MARK: - Private state

    private var currentTarget = ""
    private var openHABTrackedRootUrl = ""
    private var activeConnectionInfo: ConnectionInfo?
    private var activeConfig: ConnectionConfiguration? {
        activeConnectionInfo?.configuration
    }

    private var sseTimer: Timer?
    private var views: [UUID: WKWebView] = [:]
    private var viewAccessOrder: [UUID] = []
    private var etagChecker: ETagChecker?
    private var etagCheckerConfigURL: String?
    private var networkObservationTask: Task<Void, Never>?
    /// True while a notification's onClickAction is known to require navigating to a specific
    /// web-view path, set via `markPendingExplicitNavigation()` before the connection wait that
    /// precedes it even starts. `loadWebView` clears it the moment that explicit-path load
    /// actually runs. Guards every nil-path ("just show whatever's default/current") auto-load
    /// below, which otherwise races that explicit navigation on a cold launch — both react to
    /// the same "connection becomes active" event — and can otherwise win with the wrong
    /// (default) destination (openhab-ios#1336).
    private var hasPendingExplicitNavigation = false

    /// True once the MainUI SPA is live in the current web view and can accept
    /// client-side navigation via `window.MainUI.handleCommand`. Mirrors the state
    /// that gates command execution vs. queuing.
    var isMainUIReady: Bool {
        acceptsCommands
    }

    // MARK: - Init

    init() {
        webView = WKWebView(frame: .zero)
        observeNetworkChanges()
        observeAppLifecycle()
    }

    // MARK: - Network observation

    private func observeNetworkChanges() {
        networkObservationTask = Task { [weak self] in
            var previousConnection: ConnectionInfo?
            for await state in await NetworkTracker.shared.stateStream() {
                guard state.activeConnection != previousConnection else { continue }
                previousConnection = state.activeConnection
                self?.syncActiveConnection(with: state.activeConnection)
            }
        }
    }

    /// Reconciles the web view with the current active connection. Safe to call outside a
    /// publisher callback — e.g. on a home switch — where the stored value is up to date.
    func syncActiveConnection() {
        syncActiveConnection(with: MainActorNetworkTracker.shared.activeConnection)
    }

    /// Loads when `connection` belongs to the current home; otherwise blanks the view and
    /// waits for a valid connection. Reconciling on "does the active connection belong to
    /// the current home" is the single rule behind both a changed connection (network sink)
    /// and a changed home (home switch): a switch to a home whose connection is already
    /// active (e.g. between two demo homes) loads immediately, while a switch whose
    /// connection isn't active yet blanks without ever showing the previous home.
    private func syncActiveConnection(with connection: ConnectionInfo?) {
        Logger.notificationNavigation.info("syncActiveConnection: connection changed to \(connection?.configuration.description ?? "nil", privacy: .public) — will auto-load default path unless a notification's own load wins the race (openhab-ios#1336)")
        Task { @MainActor [weak self] in
            guard let self else { return }
            let home = await Preferences.shared.currentHomePreferences
            guard let connection, home.trackedConnections.contains(connection.configuration) else {
                clearView()
                return
            }
            openHABTrackedRootUrl = connection.configuration.url
            activeConnectionInfo = connection
            Logger.notificationNavigation.info("syncActiveConnection: connection confirmed for current home — calling loadWebView(force: false, path: nil)")
            loadWebView(force: false)
        }
        // The tracker republishes on every restart, and any preferences write restarts it,
    }

    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Logger.viewController.info("App became active, checking for content updates")
            Task { @MainActor in
                self?.loadWebView(force: false)
            }
        }
    }

    // MARK: - Loading

    /// Marks a notification-driven web-view navigation as imminent, before the connection wait
    /// that precedes it even starts. See `hasPendingExplicitNavigation`.
    func markPendingExplicitNavigation() {
        Logger.notificationNavigation.info("markPendingExplicitNavigation: default auto-loads will defer until an explicit-path load runs")
        hasPendingExplicitNavigation = true
    }

    /// Clears a pending explicit navigation once it resolves via `routeMainUI`'s client-side
    /// route (`navigateCommand`) rather than `loadWebView(path:)` — the case when Main UI is
    /// already live. Without this, a notification tap while Main UI is already showing would
    /// leave `hasPendingExplicitNavigation` stuck true forever, since `loadWebView` never runs
    /// with a non-nil path to clear it, silently blocking every later default auto-load.
    func clearPendingExplicitNavigation() {
        hasPendingExplicitNavigation = false
    }

    func loadWebView(force: Bool = false, path: String? = nil) {
        #if DEBUG
        if uiTestContentLocked {
            return
        }
        #endif
        if path != nil {
            hasPendingExplicitNavigation = false
        } else if hasPendingExplicitNavigation {
            Logger.notificationNavigation.info("loadWebView: skipping default (nil-path) auto-load — an explicit notification navigation is still pending (openhab-ios#1336)")
            return
        }
        Logger.viewController.info("loadWebView tracked URL: \(self.activeConfig?.url ?? "") forced \(force ? "true" : "false")")
        Logger.notificationNavigation.info("loadWebView: path=\(path ?? "nil", privacy: .public) force=\(force)")
        guard let activeConfig else { return }
        let authStr = "\(activeConfig.username):\(activeConfig.password)"
        let newTarget = "\(activeConfig.url):\(authStr)"

        // An explicit path always loads. The ETag shortcut compares origins only, so it
        // can't tell one route from another and would silently drop the request.
        if force || path != nil {
            Task {
                await performLoadWebView(newTarget: newTarget, path: path, force: force)
            }
            return
        }

        Task {
            await loadWebViewWithETagCheck(newTarget: newTarget, path: path)
        }
    }

    private func performLoadWebView(newTarget: String, path: String?, force: Bool) async {
        guard let activeConfig else { return }
        currentTarget = newTarget
        let url = URL(string: activeConfig.url)
        let currentPrefs = await Preferences.shared.currentHomePreferences
        let defaultPath = currentPrefs.defaultMainUIPath
        guard let modifiedUrl = WebViewURLHelper.resolveWebViewURL(
            baseURL: url,
            proxyURL: activeConnectionInfo?.proxyURL,
            path: path,
            defaultPath: defaultPath
        ) else { return }

        acceptsCommands = false
        var request = URLRequest(url: modifiedUrl)

        if force {
            let dataStore = webView.configuration.websiteDataStore
            let websiteDataTypes: Set<String> = [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]
            let date = Date(timeIntervalSince1970: 0)
            Logger.viewController.info("Force reload: clearing WKWebView cache")
            await dataStore.removeData(ofTypes: websiteDataTypes, modifiedSince: date)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        }

        let isCloudConnection = activeConfig.isCloudConnection
        let homeId = currentPrefs.id
        let newWebview = getOrCreateWebView(for: homeId, isCloudConnection: isCloudConnection)
        if newWebview !== webView {
            webView.stopLoading()
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
            webView = newWebview
        } else {}

        Logger.viewController.info("Loading URL: \(modifiedUrl)")
        // Local avoids `self.` inside the Logger interpolation, which redundantSelf would strip.
        let webViewID = ObjectIdentifier(webView).debugDescription
        Logger.notificationNavigation.info("performLoadWebView: about to call webView.load(\(modifiedUrl.absoluteString, privacy: .public)) [requestedPath=\(path ?? "nil", privacy: .public), webView=\(webViewID, privacy: .public)] — whichever load call lands here last wins the race")
        isLoading = true
        isShowingTile = false
        webView.load(request)
    }

    private func loadWebViewWithETagCheck(newTarget: String, path: String?) async {
        Logger.notificationNavigation.info("loadWebViewWithETagCheck: starting network ETag round-trip for path=\(path ?? "nil", privacy: .public) — this is the slow path most likely to land its webView.load() after a notification's direct load and clobber it")
        guard let activeConfig,
              let url = URL(string: activeConfig.url) else {
            Logger.viewController.info("ETag check skipped: invalid configuration")
            await performLoadWebView(newTarget: newTarget, path: path, force: false)
            return
        }
        let defaultPath = await (Preferences.shared.currentHomePreferences).defaultMainUIPath
        guard let fullURL = WebViewURLHelper.resolveWebViewURL(
            baseURL: url,
            proxyURL: activeConnectionInfo?.proxyURL,
            path: path,
            defaultPath: defaultPath
        ) else {
            await performLoadWebView(newTarget: newTarget, path: path, force: false)
            return
        }

        let configKey = "\(activeConfig.url):\(activeConfig.username)"
        if etagChecker == nil || etagCheckerConfigURL != configKey {
            let httpClient = HTTPClient(baseURL: nil, connectionConfiguration: activeConfig)
            etagChecker = ETagChecker(httpClient: httpClient)
            etagCheckerConfigURL = configKey
            Logger.viewController.debug("Created new ETagChecker for config: \(configKey)")
        }

        guard let checker = etagChecker else {
            await performLoadWebView(newTarget: newTarget, path: path, force: false)
            return
        }

        // Check the app shell, not the page we are loading. Every Main UI route serves the
        // same index.html, but openHAB's SPA fallback returns it without an ETag — and no
        // ETag means "changed", so checking a route would reload every time.
        let shellURL = WebViewURLHelper.resolveWebViewURL(
            baseURL: url,
            proxyURL: activeConnectionInfo?.proxyURL,
            path: nil,
            defaultPath: ""
        ) ?? fullURL
        let result = await checker.checkIfChanged(url: shellURL)

        switch result {
        case .unchanged:
            if await canKeepLoadedPage(target: fullURL) {
                Logger.viewController.info("ETag unchanged and current home's web view already shown, skipping load")
                currentTarget = newTarget
                isLoading = false
            } else {
                Logger.viewController.info("ETag unchanged but reload needed (different origin or web view), loading \(fullURL.absoluteString)")
                await performLoadWebView(newTarget: newTarget, path: path, force: false)
            }

        case .changed:
            Logger.viewController.info("ETag changed, loading \(fullURL.absoluteString)")
            await performLoadWebView(newTarget: newTarget, path: path, force: false)

        case let .failed(error):
            // A failed check is not evidence of new content. The first request after the
            // app resumes often times out, and reloading on that throws away a good page.
            if await canKeepLoadedPage(target: fullURL) {
                Logger.viewController.info("ETag check failed: \(error.localizedDescription), keeping the loaded page")
                currentTarget = newTarget
                isLoading = false
            } else {
                Logger.viewController.info("ETag check failed: \(error.localizedDescription), loading anyway")
                await performLoadWebView(newTarget: newTarget, path: path, force: false)
            }
        }
    }

    /// Loading again would only discard live SPA state.
    private func canKeepLoadedPage(target: URL) async -> Bool {
        let currentHomeWebViewShown = await views[(Preferences.shared.currentHomePreferences).id] === webView
        guard hasLoadedContent, currentHomeWebViewShown,
              lastLoadedConfiguration == activeConfig else { return false }
        let normalizedTarget = WebViewURLHelper.normalizeForComparison(target.absoluteString, includeBasePath: false)
        let normalizedLoaded = WebViewURLHelper.normalizeForComparison(lastLoadedURL, includeBasePath: false)
        Logger.viewController.debug("Comparing base URLs: loaded=\(normalizedLoaded ?? "nil") vs target=\(normalizedTarget ?? "nil")")
        guard let normalizedTarget, let normalizedLoaded else { return false }
        return normalizedTarget == normalizedLoaded
    }

    // MARK: - WKWebView instance management

    private func getOrCreateWebView(for id: UUID, isCloudConnection: Bool) -> WKWebView {
        if let existing = views[id] {
            Logger.viewController.info("Reusing webview for id:\(id.uuidString)")
            viewAccessOrder.removeAll { $0 == id }
            viewAccessOrder.append(id)
            return existing
        }

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // JS bridge is added by the Coordinator when it attaches delegates
        config.userContentController.addUserScript(
            WKUserScript(source: webViewMainUIBridgeJS, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        #if DEBUG
        config.userContentController.addUserScript(
            WKUserScript(source: webViewUITestProbeJS, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        #endif
        config.websiteDataStore = WKWebsiteDataStore(forIdentifier: id)

        let newWebView = WKWebView(frame: .zero, configuration: config)
        newWebView.scrollView.bounces = false
        newWebView.isOpaque = false
        newWebView.backgroundColor = UIColor.clear
        newWebView.scrollView.backgroundColor = UIColor.clear
        if UIDevice.current.userInterfaceIdiom == .pad {
            let sysVer = UIDevice.current.systemVersion
            let sysVerUA = sysVer.replacingOccurrences(of: ".", with: "_")
            newWebView.customUserAgent = "Mozilla/5.0 (iPad; CPU OS \(sysVerUA) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(sysVer) Mobile/15E148 Safari/604.1"
        }
        newWebView.isInspectable = true
        newWebView.scrollView.contentInsetAdjustmentBehavior = .never
        newWebView.scrollView.contentInset = .zero
        newWebView.scrollView.scrollIndicatorInsets = .zero

        views[id] = newWebView
        viewAccessOrder.append(id)
        while viewAccessOrder.count > 2 {
            let evicted = viewAccessOrder.removeFirst()
            views.removeValue(forKey: evicted)
            Logger.viewController.info("Evicted webview cache entry for id:\(evicted.uuidString)")
        }
        return newWebView
    }

    // MARK: - Navigation commands

    func navigateCommand(_ command: String) {
        if acceptsCommands {
            navigateCommandInternal(command)
        } else {
            commandQueue.append(command)
        }
    }

    private func navigateCommandInternal(_ command: String) {
        let jsCode = "window.MainUI.handleCommand('\(command)')"
        webView.evaluateJavaScript(jsCode) { _, error in
            if let error {
                Logger.viewController.error("navigateCommandInternal failed \(error.localizedDescription)")
            } else {
                Logger.viewController.info("navigateCommandInternal Success")
            }
        }
    }

    func executeQueuedCommands() {
        while !commandQueue.isEmpty {
            let command = commandQueue.removeFirst()
            navigateCommandInternal(command)
        }
    }

    // MARK: - SSE connection state

    func handleSSEConnected(_ connected: Bool) {
        isSSEConnected = connected
        if connected {
            Logger.viewController.info("WKScriptMessage sseConnected is true")
            sseTimer?.invalidate()
            acceptsCommands = true
            executeQueuedCommands()
            // SPA is live — hide the native menu bar so the SPA's own UI takes over.
            showMenuBar = false
            // Re-inject navbar proxy and re-run app-menu probe now that the SPA
            // is fully live. window.MainUI is guaranteed defined at this point.
            injectNavbarProxy()
            triggerAppMenuProbe()
        } else {
            Logger.viewController.info("WKScriptMessage sseConnected is false")
            // Show the native bar so the connection-status indicator is visible
            showMenuBar = true
            sseTimer?.invalidate()
            sseTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.acceptsCommands = false
                }
            }
        }
    }

    // MARK: - Direct URL loading (for tiles)

    func loadDirectURL(_ url: URL) {
        isLoading = true
        isShowingTile = true
        webView.load(URLRequest(url: url))
    }

    /// Loads a MainUI tile page by navigating directly to its URL.
    ///
    /// The Main UI SPA uses Framework7 with the HTML5 History API (pushState).
    /// Page URLs are clean paths — e.g. `{rootUrl}/page/EMS` — with no hash fragment.
    /// Loading the URL causes the server to return the SPA's index.html; Framework7
    /// reads the URL path on startup and routes to the correct page automatically.
    func loadTilePage(_ url: URL) {
        isLoading = true
        isShowingTile = true
        webView.load(URLRequest(url: url))
    }

    /// Reloads a tile URL bypassing HTTP caches, so the reload action fetches fresh
    /// content rather than redisplaying the cached page.
    func reloadTile(_ url: URL) {
        isLoading = true
        isShowingTile = true
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        webView.load(request)
    }

    // MARK: - Reload

    func reloadView() {
        currentTarget = ""
        commandQueue = []
        webView.stopLoading()
        webView.evaluateJavaScript("document.body.remove()")
        loadWebView(force: true)
    }

    /// Blanks the web view and resets all connection-derived state. Used whenever there is
    /// no active connection for the current home, so the previous home's page and navbar
    /// never linger and the menu bar shows its offline/connecting indicator instead.
    func clearView() {
        acceptsCommands = false
        commandQueue = []
        activeConnectionInfo = nil
        openHABTrackedRootUrl = ""
        webView.stopLoading()
        webView.load(URLRequest(url: URL(string: "about:blank")!))
        isLoading = false
        isSSEConnected = false
        hasLoadedContent = false
        showMenuBar = true
        isWebNavbarHidden = false
        isWebNavbarTitleHidden = false
        #if DEBUG
        if !uiTestContentLocked {
            navbarItems = []
            navbarTitle = ""
        }
        #else
        navbarItems = []
        navbarTitle = ""
        #endif
    }

    // MARK: - JS evaluation

    /// Evaluates an arbitrary JS expression in the current webview.
    /// Used by the native navbar proxy to trigger action buttons.
    func evaluateJS(_ js: String) {
        webView.evaluateJavaScript(js) { _, error in
            if let error {
                Logger.viewController.error("evaluateJS failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - didFinish helpers

    func handleDidFinish() {
        lastLoadedURL = webView.url?.absoluteString
        lastLoadedConfiguration = activeConfig
        isLoading = false
        acceptsCommands = true
        // A finished navigation to anything other than the blank placeholder means real
        // content is now on screen, so the "Connecting…" placeholder can be dismissed.
        if let url = webView.url?.absoluteString, !url.hasPrefix("about:") {
            hasLoadedContent = true
        }

        if let webviewURL = webView.url {
            let rootUrl = openHABTrackedRootUrl // avoids `self.` inside the Logger call below
            let url = URL(string: webviewURL.path, relativeTo: URL(string: rootUrl))
            if let path = url?.path {
                Logger.viewController.info("navigation change base: \(rootUrl) path: \(path)")
                Task {
                    await Preferences.shared.setCurrentWebViewPath(path.hasSuffix("/") ? path : path + "/")
                }
            }
        }

        injectNavbarProxy()
        injectEditorHeightFix()
        #if DEBUG
        if let encoded = ProcessInfo.processInfo.environment["UITestInjectJS"],
           let data = Data(base64Encoded: encoded),
           let jsSource = String(data: data, encoding: .utf8) {
            webView.evaluateJavaScript(jsSource, completionHandler: nil)
        }
        #endif
    }

    private func injectNavbarProxy() {
        webView.evaluateJavaScript(webViewNavbarProxyJS) { _, error in
            if let error {
                Logger.viewController.debug("navbarProxyJS: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Test support

    #if DEBUG
    func recordUITestReport(key: String, value: String) {
        uiTestReports[key] = value
    }

    /// Locks injected test state (HTML or navbar items) so that loadWebView cannot
    /// override it with real server content for the lifetime of this test run.
    func lockUITestContent() {
        uiTestContentLocked = true
    }

    /// Loads raw HTML into a fully configured webview (scripts injected).
    /// Used by UI tests via UITestInjectHTML env var — bypasses the server URL so
    /// tests work without a live openHAB instance.
    func loadHTMLString(_ html: String) async {
        uiTestContentLocked = true
        let homeId = await (Preferences.shared.currentHomePreferences).id
        let wv = getOrCreateWebView(for: homeId, isCloudConnection: false)
        if wv !== webView {
            webView = wv
        }
        wv.loadHTMLString(html, baseURL: nil)
    }
    #endif

    // MARK: - Authentication

    func resolvedURL() async -> URL? {
        guard let url = URL(string: openHABTrackedRootUrl) else { return nil }
        return await WebViewURLHelper.resolveWebViewURL(
            baseURL: url,
            proxyURL: activeConnectionInfo?.proxyURL,
            path: nil,
            defaultPath: (Preferences.shared.currentHomePreferences).defaultMainUIPath
        )
    }

    deinit {
        networkObservationTask?.cancel()
    }
}

extension OpenHABWebViewModel {
    // MARK: - Menu bar visibility

    /// Called when a new top-level navigation starts (full page load).
    /// Resets connection state and shows the bar until SSE confirms everything is live.
    func handleNavigationStart() {
        showMenuBar = true
        isSSEConnected = false
        isWebNavbarHidden = false
        isWebNavbarTitleHidden = false
        #if DEBUG
        if !uiTestContentLocked {
            navbarItems = []
            navbarTitle = ""
        }
        #else
        navbarItems = []
        navbarTitle = ""
        #endif
        // Clear the re-installation guards so the next page gets a fresh proxy.
        webView.evaluateJavaScript(
            """
            window.__ohNavbarProxyInstalled = undefined;
            window.__ohNavbarObserverInstalled = undefined;
            window.__ohNavbarLastState = undefined;
            window.__ohNavbarHeight = undefined;
            """
        )
    }

    /// Updates the proxied navbar items and title received from the web content.
    func updateNavbarItems(_ items: [WebNavbarItem], title: String = "") {
        navbarItems = items
        navbarTitle = title
    }

    /// A bad `height` reading is ignored, so it can never collapse the native bar.
    func updateNavbarState(hidden: Bool, titleHidden: Bool, height: Double?) {
        isWebNavbarHidden = hidden
        isWebNavbarTitleHidden = titleHidden
        if let height, (32.0 ... 96.0).contains(height) {
            webNavbarHeight = CGFloat(height)
        }
    }

    /// Called when the openHAB Main UI fires its `OHApp.ready()` callback.
    /// At this point the SPA has fully initialised: `window.MainUI` is defined
    /// and Vue has mounted its components, so both the proxy and probe are reliable.
    func handleReady() {
        injectNavbarProxy()
        triggerAppMenuProbe()
    }

    /// Called with the result of the JS probe that checks window.MainUI.
    /// Hides the bar only when the SPA is present AND SSE is already connected
    /// (re-entry into the webview without a full reload).
    /// - Parameter hidden: true when the Main UI is present (iOS bar would be redundant).
    func handleAppMenuProbe(hidden: Bool) {
        if hidden, isSSEConnected {
            showMenuBar = false
        } else if !hidden {
            showMenuBar = true
        }
    }

    /// Evaluates the app-menu probe immediately in the current webview.
    /// Use this when re-entering the webview content without a full page reload.
    func triggerAppMenuProbe() {
        webView.evaluateJavaScript(webViewAppMenuProbeJS)
    }

    private func injectEditorHeightFix() {
        webView.evaluateJavaScript(editorHeightFixJS(safeAreaBottom: webView.safeAreaInsets.bottom))
    }
}
