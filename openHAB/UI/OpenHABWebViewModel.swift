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

@MainActor
class OpenHABWebViewModel: ObservableObject {
    /// The host owns the bar height; the shim sizes Main UI's own navbar to match.
    static let navbarHeight: CGFloat = 44

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
    /// True once a UI test has put its own navbar in place; the page's own is ignored after that.
    private var uiTestNavbarInjected = false
    /// The same for the sidebar menu.
    private var uiTestMenuInjected = false
    #endif

    /// True once the Main UI SPA has established its SSE connection.
    @Published private(set) var isSSEConnected = false
    /// The page's navbar, as sent over the bridge. Empty until the first `navbar.state`.
    @Published private(set) var navbar = OHBridgeNavbarState.empty
    /// Main UI's sidebar, as sent over the bridge. Nil until the first `menu.state`; kept across
    /// reloads of the same home so the menu doesn't empty while a page loads.
    @Published private(set) var menu: OHBridgeMenuState?
    /// True while the web view holds a tile's URL. Its content outlives the surface that
    /// loaded it, so a sitemap detour does not put the Main UI back.
    @Published private(set) var isShowingTile = false
    /// True once a real page (not the blank placeholder) has finished loading.
    /// Drives the "Connecting…" placeholder shown while a home is first loading.
    @Published private(set) var hasLoadedContent = false

    // MARK: - Internal state (used by Coordinator)

    var lastLoadedURL: String?
    /// The connection that produced the page now on screen. Origin alone cannot tell two
    /// connections apart when only the credentials differ.
    private var lastLoadedConfiguration: ConnectionConfiguration?
    /// The bridge to Main UI in `webView`. Views tell Main UI what to do through it.
    let bridge = OHBridgeHost()
    /// What Main UI's addresses hang off on this connection, for the shim.
    private var basePath = ""
    /// The last `menu.state` from each web view, so switching homes shows that home's menu.
    private var menus: [ObjectIdentifier: OHBridgeMenuState] = [:]

    // MARK: - Private state

    private var currentTarget = ""
    private var openHABTrackedRootUrl = ""
    private var activeConnectionInfo: ConnectionInfo?
    private var activeConfig: ConnectionConfiguration? {
        activeConnectionInfo?.configuration
    }

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
    /// Which home the web view currently belongs to. Kept here so we can note pages against it
    /// right away. Looking it up takes a moment, and the user can switch homes in between.
    private var currentHomeId: UUID?

    /// True once Main UI is live in the page now loaded, so it can be navigated in place.
    var isMainUIReady: Bool {
        bridge.isMainUIReady
    }

    // MARK: - Init

    init() {
        webView = WKWebView(frame: .zero)
        bridge.webView = webView
        bridge.onEvent = { [weak self] event in self?.handleBridgeEvent(event) }
        bridge.credentials = { [weak self] in self?.proxyCredentials() }
        bridge.connectionURLs = { [weak self] in self?.connectionURLs() ?? [] }
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
    /// route (`bridge.navigate(to:)`) rather than `loadWebView(path:)` — the case when Main UI is
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

        // Put the user back where they were, unless we were asked for a particular page.
        let storedRoute = await Preferences.shared.webRouteSnapshot(for: currentPrefs.id)
        let snapshot = WebRouteRestore.snapshotToRestore(storedRoute, for: WebRouteRestore.Load(
            path: path,
            force: force,
            isShowingTile: isShowingTile
        ))
        // Settings pages need admin rights, which may differ on the other connection.
        let restore = snapshot.flatMap {
            WebRouteRestore.seed(for: $0, dropAdmin: $0.connectionURL != activeConfig.url)
        }

        // Ask for the Main UI's front page, not the page we actually want. Asking a server
        // straight for a page only works once the Main UI has been opened there at least once,
        // and after switching connection it has not, so you get a blank screen. The script then
        // moves us to the right page as the Main UI starts.
        guard let modifiedUrl = WebViewURLHelper.resolveWebViewURL(
            baseURL: url,
            proxyURL: activeConnectionInfo?.proxyURL,
            path: restore == nil ? path : nil,
            defaultPath: restore == nil ? defaultPath : ""
        ) else { return }
        // What the page addresses hang off, so a cloud connection's extra path is kept.
        let basePath = modifiedUrl.path.hasSuffix("/") ? String(modifiedUrl.path.dropLast()) : modifiedUrl.path

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
            bridge.webView = newWebview
            showMenu(of: newWebview)
        }

        self.basePath = basePath
        installUserScripts(on: webView, restore: restore?.history, props: restore?.props, basePath: basePath)

        Logger.viewController.info("Loading URL: \(modifiedUrl)")
        // Local avoids `self.` inside the Logger interpolation, which redundantSelf would strip.
        let webViewID = ObjectIdentifier(webView).debugDescription
        Logger.notificationNavigation.info("performLoadWebView: about to call webView.load(\(modifiedUrl.absoluteString, privacy: .public)) [requestedPath=\(path ?? "nil", privacy: .public), webView=\(webViewID, privacy: .public)] — whichever load call lands here last wins the race")
        isLoading = true
        isShowingTile = false
        bridge.appDidStartLoad(webView.load(request))
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
        currentHomeId = id
        if let existing = views[id] {
            Logger.viewController.info("Reusing webview for id:\(id.uuidString)")
            viewAccessOrder.removeAll { $0 == id }
            viewAccessOrder.append(id)
            return existing
        }

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = WKWebsiteDataStore(forIdentifier: id)

        let newWebView = WKWebView(frame: .zero, configuration: config)
        // The Coordinator hooks up the messages these scripts send back.
        installUserScripts(on: newWebView, restore: nil)
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
            if let evictedView = views.removeValue(forKey: evicted) {
                menus[ObjectIdentifier(evictedView)] = nil
            }
            Logger.viewController.info("Evicted webview cache entry for id:\(evicted.uuidString)")
        }
        return newWebView
    }

    // MARK: - Direct URL loading (for tiles)

    func loadDirectURL(_ url: URL) {
        loadTile(URLRequest(url: url))
    }

    /// Loads a MainUI tile page by navigating directly to its URL.
    ///
    /// The Main UI SPA uses Framework7 with the HTML5 History API (pushState).
    /// Page URLs are clean paths — e.g. `{rootUrl}/page/EMS` — with no hash fragment.
    /// Loading the URL causes the server to return the SPA's index.html; Framework7
    /// reads the URL path on startup and routes to the correct page automatically.
    func loadTilePage(_ url: URL) {
        loadTile(URLRequest(url: url))
    }

    /// Reloads a tile URL bypassing HTTP caches, so the reload action fetches fresh
    /// content rather than redisplaying the cached page.
    func reloadTile(_ url: URL) {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        loadTile(request)
    }

    /// A tile can be any site, so it loads without the bridge: nothing in it can ask the app for
    /// anything, credentials included.
    private func loadTile(_ request: URLRequest) {
        isLoading = true
        isShowingTile = true
        installTileScripts(on: webView)
        webView.load(request)
    }

    // MARK: - Reload

    func reloadView() {
        currentTarget = ""
        webView.stopLoading()
        webView.evaluateJavaScript("document.body.remove()")
        loadWebView(force: true)
    }

    /// Blanks the web view and resets all connection-derived state. Used whenever there is
    /// no active connection for the current home, so the previous home's page and navbar
    /// never linger and the menu bar shows its offline/connecting indicator instead.
    func clearView() {
        activeConnectionInfo = nil
        openHABTrackedRootUrl = ""
        webView.stopLoading()
        webView.load(URLRequest(url: URL(string: "about:blank")!))
        isLoading = false
        isSSEConnected = false
        hasLoadedContent = false
        // Nothing is on screen now, so no tile either. Left set, we would still think a tile is
        // showing and would neither put the user back nor remember where they go next.
        isShowingTile = false
        // A blank view belongs to no home yet, so its menu goes too.
        menu = nil
        resetNavbar()
    }

    // MARK: - didFinish helpers

    func handleDidFinish() {
        lastLoadedURL = webView.url?.absoluteString
        lastLoadedConfiguration = activeConfig
        isLoading = false
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

        if !isShowingTile {
            // Done with the saved pages. If the page reloads on its own later, it should stay
            // where it is rather than jump back to pages the user has since left.
            installUserScripts(on: webView, restore: nil, basePath: basePath)

            // The safe area is only known once the web view is on screen.
            bridge.updateLayout(currentLayout())
        }
        #if DEBUG
        if let encoded = ProcessInfo.processInfo.environment["UITestInjectJS"],
           let data = Data(base64Encoded: encoded),
           let jsSource = String(data: data, encoding: .utf8) {
            webView.evaluateJavaScript(jsSource, completionHandler: nil)
        }
        #endif
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

    /// Stands in for a `navbar.state` from the page.
    func setUITestNavbar(_ state: OHBridgeNavbarState) {
        uiTestNavbarInjected = true
        navbar = state
    }

    /// Stands in for a `menu.state` from the page.
    func setUITestMenu(_ state: OHBridgeMenuState) {
        uiTestMenuInjected = true
        menu = state
    }

    /// Loads raw HTML into a fully configured webview (scripts injected).
    /// Used by UI tests via UITestInjectHTML env var — bypasses the server URL so
    /// tests work without a live openHAB instance.
    func loadHTMLString(_ html: String) async {
        uiTestContentLocked = true
        bridge.acceptsLocalPages = true
        let homeId = await (Preferences.shared.currentHomePreferences).id
        let wv = getOrCreateWebView(for: homeId, isCloudConnection: false)
        if wv !== webView {
            webView = wv
            bridge.webView = wv
            showMenu(of: wv)
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

private extension OpenHABWebViewModel {
    // MARK: - Injected scripts

    /// Adds the scripts that run whenever a page opens. They go in together every time. A
    /// script's text cannot be changed once added, the list of pages to put back differs each
    /// time, and removing one script removes them all.
    func installUserScripts(on webView: WKWebView, restore: [String]?, props: [String]? = nil, basePath: String = "") {
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        bridge.installScripts(on: controller, restore: restore, props: props, basePath: basePath, layout: currentLayout())
        controller.addUserScript(
            WKUserScript(source: webViewExternalURLInterceptorJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
        #if DEBUG
        controller.addUserScript(
            WKUserScript(source: webViewUITestProbeJS, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        #endif
    }

    /// The scripts a tile gets: everything except the bridge.
    func installTileScripts(on webView: WKWebView) {
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(
            WKUserScript(source: webViewExternalURLInterceptorJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
        #if DEBUG
        controller.addUserScript(
            WKUserScript(source: webViewUITestProbeJS, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        #endif
    }
}

extension OpenHABWebViewModel {
    // MARK: - Bridge

    /// Shows the menu `webView` last sent, now that it is the one on screen.
    func showMenu(of webView: WKWebView) {
        #if DEBUG
        if uiTestMenuInjected { return }
        #endif
        menu = menus[ObjectIdentifier(webView)]
    }

    /// Called when a new top-level navigation starts (full page load). The page has to say
    /// hello again, and its bar starts empty.
    func handleNavigationStart() {
        isSSEConnected = false
        bridge.pageWillLoad()
        resetNavbar()
        // The new page sends its own menu; until then the menu falls back to the REST page list.
        menus[ObjectIdentifier(webView)] = nil
        #if DEBUG
        if uiTestMenuInjected { return }
        #endif
        menu = nil
    }

    private func resetNavbar() {
        #if DEBUG
        if uiTestNavbarInjected { return }
        #endif
        navbar = .empty
    }

    func handleBridgeEvent(_ event: OHBridgeEvent) {
        switch event {
        case let .hello(hello):
            Logger.viewController.info("OHBridge: hello from \(hello.impl.rawValue, privacy: .public), accepted \(hello.accepted, privacy: .public)")
        case let .connectionState(connected):
            isSSEConnected = connected
        case let .navChanged(state):
            handleNavChanged(state)
        case let .navbarState(state):
            #if DEBUG
            if uiTestNavbarInjected { return }
            #endif
            navbar = state
        case let .menuState(state):
            #if DEBUG
            if uiTestMenuInjected { return }
            #endif
            menus[ObjectIdentifier(webView)] = state
            menu = state
        }
    }

    /// Notes where the user is, so we can put them back later.
    ///
    /// Tiles are skipped. A tile's address is its own, and saving it would later drop the
    /// Main UI somewhere the menu never sent it.
    func handleNavChanged(_ state: OHBridgeNavState) {
        let path = state.path
        Task {
            await Preferences.shared.setCurrentWebViewPath(path)
        }
        guard let connectionURL = activeConfig?.url,
              let snapshot = WebRouteRestore.snapshot(from: state, connectionURL: connectionURL) else { return }
        guard !isShowingTile, let homeId = currentHomeId else { return }
        Task {
            await Preferences.shared.setWebRouteSnapshot(snapshot, for: homeId)
        }
    }

    /// The space the host's chrome takes over the page.
    func currentLayout() -> OHBridgeLayout {
        let insets = webView.safeAreaInsets
        return OHBridgeLayout(
            insets: .init(top: insets.top, bottom: insets.bottom),
            navbarHeight: Self.navbarHeight
        )
    }

    /// Basic auth for a reverse proxy, from the connection's settings. Nil when there is none.
    private func proxyCredentials() -> OHBridgeCredentials? {
        guard let activeConfig, !activeConfig.username.isEmpty, !activeConfig.password.isEmpty else { return nil }
        return OHBridgeCredentials(username: activeConfig.username, password: activeConfig.password)
    }

    /// Where the active connection serves Main UI: its own address, and the cloud proxy's.
    private func connectionURLs() -> [URL] {
        [activeConfig?.url, activeConnectionInfo?.proxyURL?.absoluteString]
            .compactMap(\.self)
            .compactMap(URL.init(string:))
    }
}
