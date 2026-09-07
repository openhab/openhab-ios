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
    @Published private(set) var navbarTitle: String = ""
    /// True while MainUI has hidden its own navbar (Framework7 `hide-bars-on-scroll`).
    @Published private(set) var isWebNavbarHidden = false
    /// True while an expanded large title is showing the page title instead.
    @Published private(set) var isWebNavbarTitleHidden = false
    /// MainUI's `--f7-navbar-height`, excluding the safe area. 44 on iOS, 56 on Material.
    @Published private(set) var webNavbarHeight: CGFloat = 44
    /// True once a real page (not the blank placeholder) has finished loading.
    /// Drives the "Connecting…" placeholder shown while a home is first loading.
    @Published private(set) var hasLoadedContent = false

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
        // Framework7 keeps closed popups mounted, and a page can contain one (the code
        // editor's "Parse Errors" popup sits inside the Thing page). Their navbars match
        // the same selectors as the page's own, so only count an overlay that is open.
        // Side panels are never proxied — the app's own menu replaces them.
        function isUsableNavbar(navbar) {
            if (navbar.closest('.panel')) return false;
            var overlay = navbar.closest('.popup, .sheet-modal, .dialog, .actions-modal, .login-screen');
            return !overlay || overlay.classList.contains('modal-in');
        }

        function firstUsableNavbar(selectors) {
            for (var i = 0; i < selectors.length; i++) {
                var found = document.querySelectorAll(selectors[i]);
                for (var j = 0; j < found.length; j++) {
                    if (isUsableNavbar(found[j])) return found[j];
                }
            }
            return null;
        }

        // An open popup owns the bar, otherwise the current page. A page's navbar is a
        // direct child of .page, so '> .navbar' can't match a popup nested inside it.
        function activeNavbar() {
            return firstUsableNavbar([
                '.popup.modal-in .navbar',
                '.sheet-modal.modal-in .navbar',
                '.view-main .page-current > .navbar',
                '.view-main .navbar.navbar-current',
                '.page-current > .navbar',
                '.navbar:not(.navbar-hidden)',
                '.navbar'
            ]);
        }

        function activePage() {
            return document.querySelector('.view-main .page-current')
                || document.querySelector('.page-current');
        }

        // Hide only what the native bar reproduces, and leave the navbar in the layout:
        // Framework7 sizes pages, subnavbars and absolutely positioned content (the map
        // page) from --f7-navbar-height.
        //
        // opacity, because innerText reads nothing out of a visibility:hidden subtree and
        // the labels and icons below come from these elements. A stylesheet rule, because
        // Framework7 writes inline opacity on .navbar-bg and .title as a large title
        // collapses and would overwrite ours.
        var PROXIED_CLASS = 'oh-navbar-proxied';
        function installProxyStyle() {
            if (document.getElementById('oh-navbar-proxy-style')) return;
            var style = document.createElement('style');
            style.id = 'oh-navbar-proxy-style';
            style.textContent =
                '.' + PROXIED_CLASS + ' > .navbar-bg,' +
                '.' + PROXIED_CLASS + ' > .navbar-inner > .left,' +
                '.' + PROXIED_CLASS + ' > .navbar-inner > .title,' +
                '.' + PROXIED_CLASS + ' > .navbar-inner > .nav-title,' +
                '.' + PROXIED_CLASS + ' > .navbar-inner > .right' +
                '{opacity:0 !important;pointer-events:none !important}';
            (document.head || document.documentElement).appendChild(style);
        }
        // Guard every write. classList.add/remove rewrite the attribute even when nothing
        // changes, emitting a mutation record — and this runs from the MutationObserver
        // below, so an unguarded write loops forever and pegs the main thread.
        function hideProxiedParts(navbar) {
            installProxyStyle();
            document.querySelectorAll('.' + PROXIED_CLASS).forEach(function(el) {
                if (el !== navbar) el.classList.remove(PROXIED_CLASS);
            });
            if (!navbar.classList.contains(PROXIED_CLASS)) {
                navbar.classList.add(PROXIED_CLASS);
            }
        }

        // A hideNavbar page reserves no room for the native bar, so pad it and push the
        // floating icons down. Reversible, in case the page gains a navbar later.
        function syncPagePadding(hasNavbar) {
            var page = activePage();
            if (!page) return;
            var needsPadding = !hasNavbar;
            if (needsPadding === !!page.__ohPadded) return;
            page.__ohPadded = needsPadding;
            var offset = needsPadding ? 'calc(var(--f7-navbar-height) + var(--f7-safe-area-top))' : '';
            var pc = page.querySelector('.page-content');
            if (pc) pc.style.paddingTop = offset;
            page.querySelectorAll('.sidebar-icon, .fullscreen-icon').forEach(function(el) {
                el.style.marginTop = offset;
            });
        }

        function navbarHeight() {
            var v = parseFloat(getComputedStyle(document.documentElement)
                .getPropertyValue('--f7-navbar-height'));
            return (isFinite(v) && v > 0) ? v : 44;
        }

        // Posts only on change — this runs on every scroll frame.
        var lastState = null;
        function reportState() {
            var navbar = activeNavbar();
            var hidden = navbar ? !!navbar.closest('.navbar-hidden') : false;
            // An expanded large title already shows the page title, so don't show it twice.
            var titleHidden = !!navbar &&
                navbar.classList.contains('navbar-large') &&
                !navbar.classList.contains('navbar-large-collapsed');
            var height = navbarHeight();
            var state = hidden + '|' + titleHidden + '|' + height;
            if (state === lastState) return;
            lastState = state;
            window.webkit.messageHandlers.mainUi.postMessage({
                type: 'navbarState',
                hidden: hidden ? 'true' : 'false',
                titleHidden: titleHidden ? 'true' : 'false',
                height: String(height)
            });
        }

        var statePending = false;
        function scheduleStateReport() {
            if (statePending) return;
            statePending = true;
            requestAnimationFrame(function() { statePending = false; reportState(); });
        }

        // Only mirror a navbar from what is actually on screen. The fallback selectors in
        // activeNavbar() can otherwise reach a previous page that is still mounted.
        //
        // On the iOS theme Framework7 lifts navbars out of the pages into a .navbars
        // container and marks the live one .navbar-current, so containment alone would
        // reject every page navbar there.
        function ownsBar(navbar) {
            if (!navbar) return false;
            if (navbar.closest('.popup.modal-in, .sheet-modal.modal-in')) return true;
            if (navbar.matches('.navbar-current')) return true;
            if (navbar.matches('.navbar-previous, .navbar-next, .stacked')) return false;
            var page = activePage();
            return !page || page.contains(navbar);
        }

        function serializeNavbar() {
            var navbar = activeNavbar();
            var owns = ownsBar(navbar);
            syncPagePadding(owns);
            // Nothing to mirror: clear the bar rather than leave the previous page's
            // buttons on it, whose proxy tokens are already gone.
            if (!owns) {
                window.webkit.messageHandlers.mainUi.postMessage({
                    type: 'navbarElements', title: '', items: []
                });
                reportState();
                return;
            }
            // Wait for web fonts (Framework7 Icons) to be ready before canvas rendering.
            // document.fonts.ready resolves immediately on subsequent calls once fonts are loaded.
            (document.fonts ? document.fonts.ready : Promise.resolve()).then(function() {
                hideProxiedParts(navbar);

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

                // Tokens must be unique across the document, not just within this navbar.
                // A popup sits after the main view, so a bare index would collide with the
                // page's navbar and querySelector would resolve to the page instead —
                // the popup's close button would click the hidden page behind it.
                window.__ohProxyRun = (window.__ohProxyRun || 0) + 1;
                var proxyRun = window.__ohProxyRun;
                document.querySelectorAll('[data-oh-proxy]').forEach(function(el) {
                    el.removeAttribute('data-oh-proxy');
                });

                var items = [];
                btns.forEach(function(el, idx) {
                    var inRight = !!el.closest('.navbar-inner .right');
                    // Skip right-side panel-open buttons (the web "Other Apps" drawer).
                    if (inRight && el.classList.contains('panel-open')) return;
                    // Skip the in-app exit-to-app button (F7 icon: square_arrow_right).
                    var iconChild = el.querySelector('i.icon, .icon');
                    if (inRight && iconChild && iconChild.innerText.trim() === 'square_arrow_right') return;
                    // Detect back buttons using two strategies:
                    // 1. Standard F7: element has class 'back'.
                    // 2. openHAB oh-nav-content style: a left-region button whose F7 icon
                    //    is chevron_left (iOS) or arrow_left_md (MD). These use a Vue click
                    //    handler (@click="back" → f7router.back()) instead of the F7 .back
                    //    class, so the class check alone is insufficient.
                    var f7Icon = el.querySelector('.f7-icons');
                    var iconText = f7Icon ? (f7Icon.textContent || '').trim() : '';
                    var isBack = el.classList.contains('back') ||
                        (!inRight && (iconText === 'chevron_left' || iconText === 'arrow_left_md'));
                    var label = (el.getAttribute('aria-label')
                        || el.getAttribute('title')
                        || el.innerText || '').trim();
                    // Include back buttons even without a text label; give them a
                    // fallback label so the native button has an accessibility string.
                    if (!label && !isBack) return;
                    if (!label) label = 'Back';
                    // Back links: use history.back() for standard F7 .back class.
                    // oh-nav-content style backs use a Vue click handler — proxy the click.
                    var action;
                    if (el.classList.contains('back')) {
                        action = 'window.history.back()';
                    } else {
                        var token = proxyRun + '-' + idx;
                        el.setAttribute('data-oh-proxy', token);
                        action = '(function(){var el=document.querySelector("[data-oh-proxy=\\'' + token + '\\']");if(el)el.click();})()';
                    }
                    var item = { label: label, action: action };
                    if (isBack) item.isBack = 'true';
                    var b64 = f7Icon ? iconBase64(el) : null;
                    if (b64) item.icon = b64;
                    items.push(item);
                });

                window.webkit.messageHandlers.mainUi.postMessage({
                    type: 'navbarElements',
                    title: title,
                    items: items
                });
                reportState();
            });
        }

        // Observe document.body for page transitions and popup open/close.
        // Watching .view-main alone misses popups (they are siblings of .view-main).
        // class changes on .popup.modal-in and page elements all bubble up to body.
        // Hiding runs immediately so a new page's navbar never flashes under the native
        // bar; only the expensive part (rendering icons to canvas) is debounced.
        function observeNavbar() {
            // Swift re-injects this script several times per page; without a guard each
            // injection leaves another observer and scroll listener behind.
            if (window.__ohNavbarObserverInstalled) return;
            window.__ohNavbarObserverInstalled = true;
            var root = document.body || document.documentElement;
            var timer = null;
            new MutationObserver(function() {
                var navbar = activeNavbar();
                if (navbar) hideProxiedParts(navbar);
                scheduleStateReport();
                clearTimeout(timer);
                timer = setTimeout(serializeNavbar, 200);
            }).observe(root, {
                childList: true, subtree: true,
                attributes: true, attributeFilter: ['class']
            });
            // Framework7 hides the navbar and collapses large titles from a scroll
            // handler — neither touches a class the observer above sees.
            document.addEventListener('scroll', scheduleStateReport, { capture: true, passive: true });
        }

        // Wait for the *correct* navbar. Open popups first, then .view-main.
        function readyNavbar() {
            return firstUsableNavbar([
                '.popup.modal-in .navbar',
                '.sheet-modal.modal-in .navbar',
                '.view-main .page-current > .navbar',
                '.view-main .navbar.navbar-current',
                '.page-current > .navbar'
            ]);
        }
        // A hideNavbar page never produces a navbar to wait for, so treat a rendered page
        // without one as settled too — it still needs padding and scroll state.
        function readyPageWithoutNavbar() {
            var page = activePage();
            return !!page && !!page.querySelector('.page-content') && !ownsBar(activeNavbar());
        }
        function waitAndSerialize() {
            if (readyNavbar() || readyPageWithoutNavbar()) {
                serializeNavbar();
                observeNavbar();
                return;
            }
            var root = document.body || document.documentElement;
            if (!root) return;
            var bodyObserver = new MutationObserver(function() {
                if (readyNavbar() || readyPageWithoutNavbar()) {
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
            .sink { [weak self] connection in
                // Use the value the publisher delivers, not a re-read of
                // MainActorNetworkTracker.activeConnection: @Published notifies in willSet,
                // so the stored property still holds the previous value inside this closure.
                self?.syncActiveConnection(with: connection)
            }
            .store(in: &trackerCancellables)
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
        let home = Preferences.shared.currentHomePreferences
        guard let connection, home.trackedConnections.contains(connection.configuration) else {
            clearView()
            return
        }
        // The tracker republishes on every restart, and any preferences write restarts it,
        // so re-emitting the same connection must not disturb a page that is already up.
        // Equality alone isn't enough though: two demo homes both track `.demo`, so a home
        // switch looks identical here — the web view instance is what tells them apart.
        let sameConnection = activeConnectionInfo?.configuration == connection.configuration
            && activeConnectionInfo?.proxyURL == connection.proxyURL
        openHABTrackedRootUrl = connection.configuration.url
        activeConnectionInfo = connection
        if sameConnection, hasLoadedContent, currentHomeWebViewShown {
            Logger.viewController.info("Active connection unchanged, keeping the loaded page")
            return
        }
        loadWebView(force: false)
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
        } else {
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
            if canKeepLoadedPage(target: fullURL) {
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
            if canKeepLoadedPage(target: fullURL) {
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
    private func canKeepLoadedPage(target: URL) -> Bool {
        guard hasLoadedContent, currentHomeWebViewShown else { return false }
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

    /// True when the web view on screen is this home's own instance. Homes get one each,
    /// and two homes can share a connection, so the URL alone proves nothing.
    private var currentHomeWebViewShown: Bool {
        views[Preferences.shared.currentHomePreferences.id] === webView
    }

    /// True once the MainUI SPA is live in the current web view and can accept
    /// client-side navigation via `window.MainUI.handleCommand`. Mirrors the state
    /// that gates command execution vs. queuing.
    var isMainUIReady: Bool { acceptsCommands }

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

    /// Reloads a tile URL bypassing HTTP caches, so the reload action fetches fresh
    /// content rather than redisplaying the cached page.
    func reloadTile(_ url: URL) {
        isLoading = true
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
        isLoading = false
        acceptsCommands = true
        // A finished navigation to anything other than the blank placeholder means real
        // content is now on screen, so the "Connecting…" placeholder can be dismissed.
        if let url = webView.url?.absoluteString, !url.hasPrefix("about:") {
            hasLoadedContent = true
        }

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
            "window.__ohNavbarProxyInstalled = undefined; window.__ohNavbarObserverInstalled = undefined;"
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
