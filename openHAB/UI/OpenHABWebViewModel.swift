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
    @Published private(set) var navbarTitle: String = ""

    // MARK: - Internal state (used by Coordinator)

    var acceptsCommands = false
    var commandQueue: [String] = []
    var lastLoadedURL: String?
    /// Callback fired when "exitToApp" is received from JS
    var onExitToApp: (() -> Void)?

    // MARK: - Private state

    private var currentTarget = ""
    private var openHABTrackedRootUrl = ""
    private var activeConnectionInfo: ConnectionInfo?
    private var activeConfig: ConnectionConfiguration? { activeConnectionInfo?.configuration }
    private var sseTimer: Timer?
    private var views: [UUID: WKWebView] = [:]
    private var viewAccessOrder: [UUID] = []
    private var etagChecker: ETagChecker?
    private var etagCheckerConfigURL: String?
    private var trackerCancellables = Set<AnyCancellable>()

    /// JS injected after each page load to proxy the MainUI Framework7 navbar
    /// into the native bar and hide the web navbar.
    private let navbarProxyJS = """
    (function() {
        // Returns the active/visible navbar. Popups take highest priority;
        // then the main view's current page. Scoping .view-main selectors
        // prevents the right panel ("Other Apps") from matching during
        // F7 initialisation when it briefly carries .page-current.
        function activeNavbar() {
            return document.querySelector('.popup.modal-in .navbar')
                || document.querySelector('.view-main .page-current .navbar')
                || document.querySelector('.view-main .navbar.navbar-current')
                || document.querySelector('.page-current .navbar:not(.panel *)')
                || document.querySelector('.navbar:not(.navbar-hidden):not(.panel *)')
                || document.querySelector('.navbar');
        }

        function serializeNavbar() {
            var navbar = activeNavbar();
            if (!navbar) return;
            // Wait for web fonts (Framework7 Icons) to be ready before canvas rendering.
            // document.fonts.ready resolves immediately on subsequent calls once fonts are loaded.
            (document.fonts ? document.fonts.ready : Promise.resolve()).then(function() {
                navbar.style.display = 'none';
                var navPage = navbar.closest('.page');
                var pc = (navPage && navPage.querySelector('.page-content'))
                       || document.querySelector('.view-main .page-current .page-content')
                       || document.querySelector('.page-current .page-content')
                       || document.querySelector('.page-content');
                if (pc) pc.style.paddingTop = '0px';

                var titleEl = navbar.querySelector('.title') || navbar.querySelector('[class*="title"]');
                var title = titleEl ? titleEl.innerText.trim() : '';

                // Collect interactive elements from left/right regions only —
                // avoids picking up the title text as a button label.
                var btns = Array.from(navbar.querySelectorAll(
                    '.navbar-inner .left a, .navbar-inner .left button,' +
                    '.navbar-inner .right a, .navbar-inner .right button'
                ));
                // Renders an element's icon glyph to a canvas and returns base64 PNG.
                // Drawn in black on transparent so Swift can apply template tinting.
                function iconBase64(el) {
                    try {
                        var iconEl = el.querySelector('i.icon, .icon') || el;
                        var style = window.getComputedStyle(iconEl);
                        var text = iconEl.innerText.trim() || el.innerText.trim();
                        if (!text) return null;
                        var px = 128;
                        var canvas = document.createElement('canvas');
                        canvas.width = px; canvas.height = px;
                        var ctx = canvas.getContext('2d');
                        ctx.font = 'normal ' + Math.round(px * 0.9) + 'px ' + style.fontFamily;
                        ctx.fillStyle = 'black';
                        ctx.textAlign = 'center';
                        ctx.textBaseline = 'middle';
                        ctx.fillText(text, px / 2, px / 2);
                        return canvas.toDataURL('image/png').split(',')[1];
                    } catch(e) { return null; }
                }

                var items = [];
                btns.forEach(function(el, idx) {
                    var inRight = !!el.closest('.navbar-inner .right');
                    // Skip right-side panel-open buttons (the web "Other Apps" drawer).
                    if (inRight && el.classList.contains('panel-open')) return;
                    // Skip the in-app exit-to-app button (F7 icon: square_arrow_right).
                    var iconChild = el.querySelector('i.icon, .icon');
                    if (inRight && iconChild && iconChild.innerText.trim() === 'square_arrow_right') return;
                    var label = (el.getAttribute('aria-label')
                        || el.getAttribute('title')
                        || el.innerText || '').trim();
                    if (!label) return;
                    // Back links: use history.back() — clicking the hidden element
                    // is ignored by F7. All other buttons: tag and click.
                    var action;
                    if (el.classList.contains('back')) {
                        action = 'window.history.back()';
                    } else {
                        el.setAttribute('data-oh-proxy', String(idx));
                        action = '(function(){var el=document.querySelector("[data-oh-proxy=\\'' + idx + '\\']");if(el)el.click();})()';
                    }
                    var item = { label: label, action: action };
                    var b64 = el.querySelector('.f7-icons') ? iconBase64(el) : null;
                    if (b64) item.icon = b64;
                    items.push(item);
                });

                window.webkit.messageHandlers.mainUi.postMessage({
                    type: 'navbarElements',
                    title: title,
                    items: items
                });
            });
        }

        // Observe document.body for page transitions and popup open/close.
        // Watching .view-main alone misses popups (they are siblings of .view-main).
        // class changes on .popup.modal-in and page elements all bubble up to body.
        // Debounced 200 ms.
        function observeNavbar() {
            var root = document.body || document.documentElement;
            var timer = null;
            new MutationObserver(function() {
                clearTimeout(timer);
                timer = setTimeout(serializeNavbar, 200);
            }).observe(root, {
                childList: true, subtree: true,
                attributes: true, attributeFilter: ['class']
            });
        }

        // Wait for the *correct* navbar. Popups first, then .view-main.
        function readyNavbar() {
            return document.querySelector('.popup.modal-in .navbar')
                || document.querySelector('.view-main .page-current .navbar')
                || document.querySelector('.view-main .navbar.navbar-current')
                || document.querySelector('.page-current .navbar:not(.panel *)');
        }
        function waitAndSerialize() {
            if (readyNavbar()) {
                serializeNavbar();
                observeNavbar();
                return;
            }
            var root = document.body || document.documentElement;
            if (!root) return;
            var bodyObserver = new MutationObserver(function() {
                if (readyNavbar()) {
                    bodyObserver.disconnect();
                    serializeNavbar();
                    observeNavbar();
                }
            });
            // Watch childList for new elements AND attributes for .page-current
            // being added to an existing element.
            bodyObserver.observe(root, { childList: true, subtree: true,
                                         attributes: true, attributeFilter: ['class'] });
        }

        // Guard against re-installation when Swift injects this script multiple
        // times (on ready, sseConnected, didFinish). Only set up history hooks once;
        // always re-run waitAndSerialize so a fresh page or SPA navigation is covered.
        if (window.__ohNavbarProxyInstalled) {
            waitAndSerialize();
            return;
        }
        window.__ohNavbarProxyInstalled = true;

        waitAndSerialize();

        // Re-run after SPA navigations. requestAnimationFrame fires after the
        // browser's next paint, by which time Framework7 has updated the navbar.
        var origPush = history.pushState;
        history.pushState = function() {
            origPush.apply(this, arguments);
            requestAnimationFrame(waitAndSerialize);
        };
        var origReplace = history.replaceState;
        history.replaceState = function() {
            origReplace.apply(this, arguments);
            requestAnimationFrame(waitAndSerialize);
        };
        window.addEventListener('popstate', function() {
            requestAnimationFrame(waitAndSerialize);
        });
    })();
    """

    private let js = """
    (function() {
        // App-menu button probe.
        // window.MainUI is the global registered by the openHAB Main UI SPA.
        // Its presence means the Main UI is loaded and its own exit-to-app
        // button is available, so the iOS floating button is redundant.
        var _probeTimer = null;
        function probeMainUIButton() {
            var isOnMainUI = (typeof window.MainUI !== 'undefined');
            window.webkit.messageHandlers.mainUi.postMessage(
                isOnMainUI ? 'appMenu-hidden' : 'appMenu-visible'
            );
        }
        function scheduleProbe() {
            if (_probeTimer !== null) { clearTimeout(_probeTimer); }
            _probeTimer = setTimeout(function() { _probeTimer = null; probeMainUIButton(); }, 800);
        }

        // Main UI Callbacks
        window.OHApp = {
            exitToApp : function(){
                window.webkit.messageHandlers.mainUi.postMessage('exitToApp');
            },
            goFullscreen : function(){
                window.webkit.messageHandlers.mainUi.postMessage('goFullscreen');
            },
            sseConnected : function(connected) {
                window.webkit.messageHandlers.mainUi.postMessage('sseConnected-' + connected);
            },
            ready : function() {
                window.webkit.messageHandlers.mainUi.postMessage('ready');
            },
        }

        // Detect Path changes in SPA
        function notifyPathChange() {
            window.webkit.messageHandlers.pathChanged.postMessage(window.location.pathname);
            scheduleProbe();
        }

        const originalPushState = history.pushState;
        history.pushState = function() {
            originalPushState.apply(this, arguments);
            notifyPathChange();
        };

        const originalReplaceState = history.replaceState;
        history.replaceState = function() {
            originalReplaceState.apply(this, arguments);
            notifyPathChange();
        };

        window.addEventListener('popstate', notifyPathChange);

        // Notify initial path on load and run initial probe
        notifyPathChange();
    })();
    """

    // MARK: - Init

    init() {
        webView = WKWebView(frame: .zero)
        observeNetworkChanges()
        observeAppLifecycle()
    }

    // MARK: - Network observation

    private func observeNetworkChanges() {
        MainActorNetworkTracker.shared.$activeConnection
            .sink { [weak self] activeConnection in
                guard let self, let activeConnection else { return }
                let activeConfiguration = activeConnection.configuration
                Logger.viewController.info("OpenHABWebView openHAB URL = \(activeConfiguration.url)")
                self.openHABTrackedRootUrl = activeConfiguration.url
                self.activeConnectionInfo = activeConnection
                self.loadWebView(force: false)
            }
            .store(in: &trackerCancellables)
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

    func loadWebView(force: Bool = false, path: String? = nil) {
        #if DEBUG
        if uiTestContentLocked { return }
        #endif
        Logger.viewController.info("loadWebView tracked URL: \(self.activeConfig?.url ?? "") forced \(force ? "true" : "false")")
        guard let activeConfig else { return }
        let authStr = "\(activeConfig.username):\(activeConfig.password)"
        let newTarget = "\(activeConfig.url):\(authStr)"

        if force {
            Task {
                await performLoadWebView(newTarget: newTarget, path: path, force: true)
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
        let defaultPath = Preferences.shared.currentHomePreferences.defaultMainUIPath
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
        let homeId = Preferences.shared.currentHomePreferences.id
        let newWebview = getOrCreateWebView(for: homeId, isCloudConnection: isCloudConnection)
        if newWebview !== webView {
            webView.stopLoading()
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
            webView = newWebview
        }

        Logger.viewController.info("Loading URL: \(modifiedUrl)")
        isLoading = true
        webView.load(request)
    }

    private func loadWebViewWithETagCheck(newTarget: String, path: String?) async {
        guard let activeConfig,
              let url = URL(string: activeConfig.url) else {
            Logger.viewController.info("ETag check skipped: invalid configuration")
            await performLoadWebView(newTarget: newTarget, path: path, force: false)
            return
        }
        let defaultPath = Preferences.shared.currentHomePreferences.defaultMainUIPath
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

        let result = await checker.checkIfChanged(url: fullURL)

        switch result {
        case .unchanged:
            let normalizedTarget = WebViewURLHelper.normalizeForComparison(fullURL.absoluteString, includeBasePath: false)
            let normalizedLoaded = WebViewURLHelper.normalizeForComparison(lastLoadedURL, includeBasePath: false)
            Logger.viewController.debug("ETag unchanged - comparing base URLs: loaded=\(normalizedLoaded ?? "nil") vs target=\(normalizedTarget ?? "nil")")

            if let normalizedTarget, let normalizedLoaded, normalizedLoaded == normalizedTarget {
                Logger.viewController.info("ETag unchanged and same base URL, skipping load")
                currentTarget = newTarget
                isLoading = false
            } else {
                Logger.viewController.info("ETag unchanged but different base URL, loading \(fullURL.absoluteString)")
                await performLoadWebView(newTarget: newTarget, path: path, force: false)
            }

        case .changed:
            Logger.viewController.info("ETag changed, loading \(fullURL.absoluteString)")
            await performLoadWebView(newTarget: newTarget, path: path, force: false)

        case let .failed(error):
            Logger.viewController.info("ETag check failed: \(error.localizedDescription), loading anyway")
            await performLoadWebView(newTarget: newTarget, path: path, force: false)
        }
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
            WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        #if DEBUG
        let ohUITestJS = """
        (function(){
          if(window.ohUITest)return;
          window.ohUITest={report:function(k,v){
            if(window.webkit&&window.webkit.messageHandlers.mainUi)
              window.webkit.messageHandlers.mainUi.postMessage(
                {type:'uiTestReport',key:String(k),value:String(v)});
          }};
        })();
        """
        config.userContentController.addUserScript(
            WKUserScript(source: ohUITestJS, injectionTime: .atDocumentStart, forMainFrameOnly: false)
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
        webView.load(URLRequest(url: url))
    }

    // MARK: - Reload

    func reloadView() {
        currentTarget = ""
        commandQueue = []
        webView.stopLoading()
        webView.evaluateJavaScript("document.body.remove()")
        loadWebView(force: true)
    }

    /// Blanks the webview immediately by loading `about:blank`.
    /// Use this before a home switch so the previous home's content
    /// disappears instantly, before the new connection is established.
    func clearView() {
        acceptsCommands = false
        commandQueue = []
        webView.stopLoading()
        webView.load(URLRequest(url: URL(string: "about:blank")!))
        isLoading = true
        isSSEConnected = false
        showMenuBar = true
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
        isLoading = false
        acceptsCommands = true

        if let webviewURL = webView.url {
            let url = URL(string: webviewURL.path, relativeTo: URL(string: openHABTrackedRootUrl))
            if let path = url?.path {
                Logger.viewController.info("navigation change base: \(self.openHABTrackedRootUrl) path: \(path)")
                Preferences.shared.currentWebViewPath = path.hasSuffix("/") ? path : path + "/"
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
        webView.evaluateJavaScript(navbarProxyJS) { _, error in
            if let error {
                Logger.viewController.debug("navbarProxyJS: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Menu bar visibility

    /// Called when a new top-level navigation starts (full page load).
    /// Resets connection state and shows the bar until SSE confirms everything is live.
    func handleNavigationStart() {
        showMenuBar = true
        isSSEConnected = false
        #if DEBUG
        if !uiTestContentLocked {
            navbarItems = []
            navbarTitle = ""
        }
        #else
        navbarItems = []
        navbarTitle = ""
        #endif
        // Clear the re-installation guard so the next page gets a fresh proxy.
        webView.evaluateJavaScript("window.__ohNavbarProxyInstalled = undefined;")
    }

    /// Updates the proxied navbar items and title received from the web content.
    func updateNavbarItems(_ items: [WebNavbarItem], title: String = "") {
        navbarItems = items
        navbarTitle = title
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
        let probeJS = """
        (function() {
            var isOnMainUI = (typeof window.MainUI !== 'undefined');
            window.webkit.messageHandlers.mainUi.postMessage(
                isOnMainUI ? 'appMenu-hidden' : 'appMenu-visible'
            );
        })();
        """
        webView.evaluateJavaScript(probeJS)
    }

    private func injectEditorHeightFix() {
        let safeAreaBottom = webView.safeAreaInsets.bottom
        let editorFixJS = """
        (function() {
            if (window.__ohEditorFixInstalled) return;
            window.__ohEditorFixInstalled = true;

            var safeAreaBottom = \(safeAreaBottom);

            function fixScriptEditorHeight() {
                var editor = document.querySelector('.rule-script-editor.v-codemirror');
                if (!editor) return;

                var page = editor.closest('.page');
                if (!page) return;

                var toolbar = page.querySelector('.toolbar');
                if (!toolbar) return;

                var fab = page.querySelector('.fab') || document.querySelector('.fab');
                var fabHeight = 0;
                if (fab) {
                    var fabRect = fab.getBoundingClientRect();
                    fabHeight = fabRect.height || 56;
                }

                var totalBottomPadding = safeAreaBottom;
                if (fab && fabHeight > 0) {
                    totalBottomPadding += fabHeight + 16;
                } else if (fab) {
                    totalBottomPadding += 56 + 16;
                }

                var pageContent = page.querySelector('.page-content');
                if (pageContent) {
                    pageContent.style.paddingBottom = totalBottomPadding + 'px';
                }

                var scrollContainer = editor.querySelector('.cm-scroller') ||
                                     editor.querySelector('.CodeMirror-scroll') ||
                                     editor.querySelector('.cm-content');

                if (scrollContainer && scrollContainer !== editor) {
                    scrollContainer.style.paddingBottom = totalBottomPadding + 'px';
                    scrollContainer.style.overflowY = 'auto';
                    editor.style.marginBottom = totalBottomPadding + 'px';
                } else {
                    editor.style.paddingBottom = totalBottomPadding + 'px';
                    editor.style.marginBottom = totalBottomPadding + 'px';
                }
            }

            new MutationObserver(function(mutations) {
                for (var i = 0; i < mutations.length; i++) {
                    for (var j = 0; j < mutations[i].addedNodes.length; j++) {
                        var n = mutations[i].addedNodes[j];
                        if (n.nodeType === 1 &&
                            ((n.classList && n.classList.contains('rule-script-editor')) ||
                             (n.querySelector && n.querySelector('.rule-script-editor')))) {
                            setTimeout(function() {
                                requestAnimationFrame(fixScriptEditorHeight);
                            }, 100);
                            return;
                        }
                    }
                }
            }).observe(document.body || document.documentElement, { subtree: true, childList: true });

            window.addEventListener('resize', function() {
                setTimeout(function() {
                    requestAnimationFrame(fixScriptEditorHeight);
                }, 100);
            });

            setTimeout(function() {
                fixScriptEditorHeight();
            }, 500);
        })();
        """
        webView.evaluateJavaScript(editorFixJS)
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
    func loadHTMLString(_ html: String) {
        uiTestContentLocked = true
        let wv = getOrCreateWebView(for: Preferences.shared.currentHomePreferences.id, isCloudConnection: false)
        if wv !== webView { webView = wv }
        wv.loadHTMLString(html, baseURL: nil)
    }
    #endif

    // MARK: - Authentication

    func resolvedURL() -> URL? {
        guard let url = URL(string: openHABTrackedRootUrl) else { return nil }
        return WebViewURLHelper.resolveWebViewURL(
            baseURL: url,
            proxyURL: activeConnectionInfo?.proxyURL,
            path: nil,
            defaultPath: Preferences.shared.currentHomePreferences.defaultMainUIPath
        )
    }
}
