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
import SideMenu
import SwiftMessages
import UIKit
import WebKit

class OpenHABWebViewController: OpenHABViewController {
    private var currentTarget = ""
    private var openHABTrackedRootUrl = ""
    private var activeConnectionInfo: ConnectionInfo?
    private var activeConfig: ConnectionConfiguration? { activeConnectionInfo?.configuration }
    private var hideNavigationBar = false
    private var activityIndicator: UIActivityIndicatorView!
    private var sseTimer: Timer?
    private var commandQueue: [String] = []
    private var acceptsCommands = false
    private var views: [UUID: WKWebView] = [:]
    // TODO: remove myOhViews when we drop iOS 16 support
    private var myOhViews: [UUID: WKWebView] = [:]
    private var etagChecker: ETagChecker?
    private var etagCheckerConfigURL: String? // Track which config the checker was created for
    private var lastLoadedURL: String? // Track the last successfully loaded URL from didFinish

    private var js = """
    (function() {
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

        // Notify initial path on load
        notifyPathChange();
    })();
    """

    override open var shouldAutorotate: Bool {
        true
    }

    private var webView: WKWebView = .init(frame: .zero)

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        attachWebViewToLayout(webView)
        activityIndicator = UIActivityIndicatorView()
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.style = UIActivityIndicatorView.Style.large

        view.addSubview(activityIndicator)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setHideNavigationBar(shouldHide: hideNavigationBar, animated: animated)
        navigationController?.navigationBar.prefersLargeTitles = false
        parent?.navigationItem.title = "Main View"
        MainActorNetworkTracker.shared.$activeConnection
            .receive(on: DispatchQueue.main)
            .sink { activeConnection in
                if let activeConnection {
                    let activeConfiguration = activeConnection.configuration
                    Logger.viewController.info("OpenHABWebViewController openHAB URL = \(activeConfiguration.url)")
                    self.openHABTrackedRootUrl = activeConfiguration.url
                    self.activeConnectionInfo = activeConnection
                    self.loadWebView(force: false)
                }
            }
            .store(in: &trackerCancellables)

        // Listen for app becoming active to check for content updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        startTracker()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Show the navigation bar on other view controllers
        // do not change the "navigationBarHidden" flag to restore on reappearing
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        trackerCancellables.removeAll()

        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    func startTracker() {
        if currentTarget.isEmpty {
            showActivityIndicator(show: true)
        }
    }

    @objc private func applicationDidBecomeActive() {
        // When app returns from background, check if content has changed
        Logger.viewController.info("App became active, checking for content updates")
        loadWebView(force: false)
    }

    @MainActor
    func loadWebView(force: Bool = false, path: String? = nil) {
        Logger.viewController.info("loadWebView tracked URL: \(self.activeConfig?.url ?? "") forced \(force ? "true" : "false")")
        guard let activeConfig else { return }
        // TODO: Check whether credentials are truly put into newTarget
        let authStr = "\(activeConfig.username):\(activeConfig.password)"
        let newTarget = "\(activeConfig.url):\(authStr)"

        // If force reload, skip ETag check and always reload
        if force {
            Task {
                await performLoadWebView(newTarget: newTarget, path: path, force: true)
            }
            return
        }

        // Check ETag before loading (even if target hasn't changed - content might have updated)
        Task {
            await loadWebViewWithETagCheck(newTarget: newTarget, path: path)
        }
    }

    @MainActor
    private func performLoadWebView(newTarget: String, path: String?, force: Bool) async {
        guard let activeConfig else { return }
        currentTarget = newTarget
        let url = URL(string: activeConfig.url)

        if let modifiedUrl = modifyUrl(orig: url, path: path) {
            acceptsCommands = false
            var request = URLRequest(url: modifiedUrl)

            // When force reloading, bypass ALL caches (both URLRequest and WKWebView)
            if force {
                // Clear WKWebView's internal cache
                let dataStore = webView.configuration.websiteDataStore
                let websiteDataTypes: Set<String> = [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]
                let date = Date(timeIntervalSince1970: 0)

                Logger.viewController.info("Force reload: clearing WKWebView cache")
                await dataStore.removeData(ofTypes: websiteDataTypes, modifiedSince: date)

                // Set aggressive cache policy for URLRequest
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            }

            // TODO: remove this check once iOS 16 is dropped
            let isCloudConnection = activeConfig.isCloudConnection
            // create new (or resuse existing)
            let newWebview = webView(for: Preferences.shared.currentHomePreferences.id, isCloudConnection: isCloudConnection)
            if newWebview != webView {
                // Detach old instance
                webView.stopLoading()
                webView.navigationDelegate = nil
                webView.uiDelegate = nil
                webView.removeFromSuperview()
                newWebview.navigationDelegate = self
                newWebview.uiDelegate = self
                webView = newWebview
                attachWebViewToLayout(newWebview)
            }
            Logger.viewController.info("Loading URL: \(modifiedUrl)")
            webView.load(request)
        }
    }

    @MainActor
    private func loadWebViewWithETagCheck(newTarget: String, path: String?) async {
        guard let activeConfig,
              let url = URL(string: activeConfig.url),
              let fullURL = modifyUrl(orig: url, path: path) else {
            Logger.viewController.info("ETag check skipped: invalid configuration")
            await performLoadWebView(newTarget: newTarget, path: path, force: false)
            return
        }

        // Create checker if needed (lazy initialization) or if config changed
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

        // Check if content changed
        let result = await checker.checkIfChanged(url: fullURL)

        switch result {
        case .unchanged:
            // When ETag is unchanged, the base resource (HTML/JS) hasn't changed
            // Compare base URLs (origin) only, since paths are handled by client-side routing
            let normalizedTarget = normalizeURLForComparison(fullURL.absoluteString, includeBasePath: false)
            let normalizedLoaded = normalizeURLForComparison(lastLoadedURL, includeBasePath: false)

            Logger.viewController.debug("ETag unchanged - comparing base URLs: loaded=\(normalizedLoaded ?? "nil") vs target=\(normalizedTarget ?? "nil")")

            if let normalizedTarget, let normalizedLoaded, normalizedLoaded == normalizedTarget {
                Logger.viewController.info("ETag unchanged and same base URL, skipping load")
                currentTarget = newTarget
                showActivityIndicator(show: false)
                // Don't load - same server, same content version, already displayed
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

    /// Normalizes URLs for comparison
    /// - Parameters:
    ///   - urlString: The URL string to normalize
    ///   - includeBasePath: If true, includes the path component; if false, returns only the base URL (origin)
    /// - Returns: Normalized URL string
    private func normalizeURLForComparison(_ urlString: String?, includeBasePath: Bool = false) -> String? {
        guard let urlString, let url = URL(string: urlString) else { return nil }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        // Always remove fragment (everything after #)
        components?.fragment = nil

        // For base URL comparison (when includeBasePath == false), remove the path entirely
        if !includeBasePath {
            components?.path = ""
            components?.query = nil
        }

        guard var normalized = components?.url?.absoluteString else { return nil }

        // Remove trailing slash for consistent comparison
        if normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }

        return normalized
    }

    func modifyUrl(orig: URL?, path: String? = nil) -> URL? {
        // better way to clone/copy ?
        guard let urlString = orig?.absoluteString, var url = URL(string: urlString) else { return orig }
        // Use cloud proxy URL if available (resolved from /api/v1/proxyurl)
        if let proxyURL = activeConnectionInfo?.proxyURL {
            url = proxyURL
        }
        if let path {
            url = appendPathToURL(baseURL: url, path: path) ?? url
        } else if !Preferences.shared.currentHomePreferences.defaultMainUIPath.isEmpty {
            url = appendPathToURL(baseURL: url, path: Preferences.shared.currentHomePreferences.defaultMainUIPath) ?? url
        }
        return url
    }

    // swift really makes you work to construct simple URLs, uhg.....
    func appendPathToURL(baseURL: URL, path: String) -> URL? {
        guard var urlComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        // Split the user path into path and query components
        if let questionMarkRange = path.range(of: "?") {
            // Separate path and query
            let pathComponent = String(path[..<questionMarkRange.lowerBound])
            let queryComponent = String(path[questionMarkRange.upperBound...])
            // Append the path component
            urlComponents.path = (urlComponents.path as NSString).appendingPathComponent(pathComponent)
            // Append the query component
            urlComponents.query = queryComponent
        } else {
            // No query in the path, just append the path
            urlComponents.path = (urlComponents.path as NSString).appendingPathComponent(path)
        }
        // Return the constructed URL
        return urlComponents.url
    }

    func showActivityIndicator(show: Bool) {
        if show {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    func setHideNavigationBar(shouldHide: Bool, animated: Bool = true) {
        Logger.viewController.debug("Hide navigation bar: \(shouldHide)")
        hideNavigationBar = shouldHide
        navigationController?.setNavigationBarHidden(hideNavigationBar, animated: animated)
    }

    func clearExistingPage() {
        Logger.viewController.info("clearExistingPage")
        setHideNavigationBar(shouldHide: false)
        // clear out existing page while we load.
        webView.stopLoading()
        webView.evaluateJavaScript("document.body.remove()")
    }

    func pageLoadError(message: String) {
        showActivityIndicator(show: true)
        showPopupMessage(seconds: 60, title: String(localized: "Error", comment: ""), message: message, theme: .error)
    }

    // swiftformat:enable redundantSelf

    override func reloadView() {
        currentTarget = ""
        clearExistingPage()
        startTracker()
        loadWebView(force: true)
    }

    override func viewName() -> String {
        "web"
    }

    func navigateCommand(_ command: String) {
        if acceptsCommands {
            navigateCommandInternal(command)
        } else {
            commandQueue.append(command)
        }
    }

    private func navigateCommandInternal(_ command: String) {
        // let jsCode = "window.OHApp.navigate === 'function' && window.OHApp.navigate('\(command)')"
        let jsCode = "window.MainUI.handleCommand('\(command)')"
        webView.evaluateJavaScript(jsCode) { (_, error) in
            if let error {
                Logger.viewController.error("navigateCommandInternal failed \(error.localizedDescription)")
            } else {
                Logger.viewController.info("navigateCommandInternal Success")
            }
        }
    }

    private func executeQueuedCommands() {
        while !commandQueue.isEmpty {
            let command = commandQueue.removeFirst()
            navigateCommandInternal(command)
        }
    }

    func webView(for id: UUID, isCloudConnection: Bool) -> WKWebView {
        // TODO: remove all iOS < 17 code when we drop iOS 16 support
        if #unavailable(iOS 17) {
            if isCloudConnection, let myExsiting = myOhViews[id] {
                Logger.viewController.info("Reusing cloud webview for id:\(id.uuidString)")
                return myExsiting
            }
        }
        if let existing = views[id] {
            Logger.viewController.info("Reusing webview for id:\(id.uuidString)")
            return existing
        }
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // adds: window.webkit.messageHandlers.xxxx.postMessage to JS env
        config.userContentController.add(self, name: "mainUi")
        config.userContentController.add(self, name: "pathChanged")
        config.userContentController.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))

        // iOS 17 allows Sandboxed profiles, which is fantastic, iOS 16 does not and agressively caches everything
        if #available(iOS 17, *) {
            config.websiteDataStore = WKWebsiteDataStore(forIdentifier: id)
        } else if isCloudConnection {
            // for cloud connections, create an instance that does not persist or share states (private)
            config.websiteDataStore = .nonPersistent()
        }

        let webview = WKWebView(frame: .zero, configuration: config)
        webview.navigationDelegate = self
        webview.uiDelegate = self
        webview.scrollView.bounces = false
        // support dark mode and avoid white flashing when loading
        webview.isOpaque = false
        webview.backgroundColor = UIColor.clear
        if UIDevice.current.userInterfaceIdiom == .pad {
            // since ios 13 Safari sets the user agent to desktop mode on iPads so the view renders correctly with larger screens
            webview.customUserAgent = "Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        }
        if #available(iOS 16.4, *) {
            webview.isInspectable = true
        }

        // Avoid safe-area content insets which can leave a small gap at the bottom on iPad until a reload.
        webview.scrollView.contentInsetAdjustmentBehavior = .never
        webview.scrollView.contentInset = .zero
        webview.scrollView.scrollIndicatorInsets = .zero

        if #unavailable(iOS 17) {
            if isCloudConnection {
                myOhViews[id] = webview
                return webview
            }
        }
        views[id] = webview
        return webview
    }

    func attachWebViewToLayout(_ webView: WKWebView) {
        if webView.superview !== view {
            view.addSubview(webView)
        }
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
}

extension OpenHABWebViewController: WKScriptMessageHandler {
    @MainActor
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        Logger.viewController.info("WKScriptMessage \(message.name)")
        if message.name == "pathChanged", let newPath = message.body as? String {
            Logger.viewController.debug("Path changed to: \(newPath)")
            Task { @MainActor in
                Preferences.shared.currentWebViewPath = newPath
            }
        }
        if message.name == "mainUi", let callbackName = message.body as? String {
            Logger.viewController.info("WKScriptMessage \(callbackName)")
            switch callbackName {
            case "exitToApp":
                showSideMenu()
            case "goFullscreen":
                // check to make sure we are actually the top view before hiding the nav button
                if isViewLoaded, view.window != nil {
                    setHideNavigationBar(shouldHide: true)
                }
            case "sseConnected-true":
                Logger.viewController.info("WKScriptMessage sseConnected is true")
                hidePopupMessages()
                sseTimer?.invalidate()
                acceptsCommands = true
                executeQueuedCommands()
            case "sseConnected-false":
                Logger.viewController.info("WKScriptMessage sseConnected is false")
                sseTimer?.invalidate()
                sseTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    Task { @MainActor in
                        self.showPopupMessage(seconds: 20, title: String(localized: "connecting", comment: ""), message: "", theme: .info)
                        self.acceptsCommands = false
                    }
                }
            default: break
            }
        }
    }
}

extension OpenHABWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .allow }
        Logger.viewController.info("decidePolicyFor - url: \(url.absoluteString)")

        if navigationAction.navigationType == .linkActivated {
            await UIApplication.shared.open(url)
            return .cancel // Stop in WebView
        }
        return .allow
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        if let response = navigationResponse.response as? HTTPURLResponse {
            Logger.viewController.info("navigationResponse: \(response.statusCode)")

            if response.statusCode >= 400 {
                pageLoadError(message: "\(response.statusCode)")
                return .cancel
            }
        }
        return .allow
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
        Logger.viewController.info("didStartProvisionalNavigation - webView.url: \(String(describing: webView.url?.description))")
        showActivityIndicator(show: true)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: any Error) {
        Logger.viewController.error("didFail - webView.url: \(String(describing: webView.url?.description))")

        setHideNavigationBar(shouldHide: false)
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return // Ignore cancelled requests
        }

        pageLoadError(message: error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Logger.viewController.info("didFinish - webView.url: \(String(describing: webView.url?.description))")

        // Fix: the Main UI script editor height does not account for the bottom toolbar's safe area
        // padding on iPhone, so the last few lines are hidden behind the toolbar (issue #1092).
        // Add padding to account for safe area and FAB button at the bottom.
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

                // Find FAB button and calculate total padding needed
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

                // Add padding to page content
                var pageContent = page.querySelector('.page-content');
                if (pageContent) {
                    pageContent.style.paddingBottom = totalBottomPadding + 'px';
                }

                // Add padding to CodeMirror scroll container
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

            // Watch for editor appearing via MutationObserver
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

            // Watch for window resize events
            window.addEventListener('resize', function() {
                setTimeout(function() {
                    requestAnimationFrame(fixScriptEditorHeight);
                }, 100);
            });

            // Initial fix attempt
            setTimeout(function() {
                fixScriptEditorHeight();
            }, 500);
        })();
        """
        webView.evaluateJavaScript(editorFixJS)

        // Track the successfully loaded URL for ETag comparison
        lastLoadedURL = webView.url?.absoluteString

        setHideNavigationBar(shouldHide: true)
        showActivityIndicator(show: false)
        hidePopupMessages()
        acceptsCommands = true
        // watch for URL changes so we can store the last visited path
        if let webviewURL = webView.url {
            let url = URL(string: webviewURL.path, relativeTo: URL(string: openHABTrackedRootUrl))
            if let path = url?.path {
                let string = openHABTrackedRootUrl
                Logger.viewController.info("navigation change base: \(string) path: \(path)")
                Task { @MainActor in
                    Preferences.shared.currentWebViewPath = path.hasSuffix("/") ? path : path + "/"
                }
            }
        }
    }

    func webView(_ webView: WKWebView, respondTo challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        Logger.viewController.info("Challenge.protectionSpace.authenticationMethod: \(String(describing: challenge.protectionSpace.authenticationMethod))")

        if let url = modifyUrl(orig: URL(string: openHABTrackedRootUrl)), challenge.protectionSpace.host == url.host {
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                guard let serverTrust = challenge.protectionSpace.serverTrust else {
                    return (.performDefaultHandling, nil)
                }
                let credential = URLCredential(trust: serverTrust)
                return (.useCredential, credential)
            } else {
                if challenge.protectionSpace.authenticationMethod.isAny(of: NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodDefault) {
                    return await onReceiveSessionTaskChallenge(with: challenge)
                } else {
                    return await onReceiveSessionChallenge(with: challenge)
                }
            }
        }
        return (.performDefaultHandling, nil)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        Logger.viewController.warning("webViewWebContentProcessDidTerminate - reloading view")
        reloadView()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        setHideNavigationBar(shouldHide: false)
        reloadView()
    }
}

extension OpenHABWebViewController: WKUIDelegate {
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        let schemes = ["http", "https"]
        if navigationAction.targetFrame == nil,
           let url = navigationAction.request.url,
           let scheme = url.scheme,
           schemes.contains(scheme) {
            let svc = SFSafariViewController(url: url)
            present(svc, animated: true, completion: nil)
        }

        return nil
    }

    func webView(_ webView: WKWebView,
                 decideMediaCapturePermissionsFor origin: WKSecurityOrigin,
                 initiatedBy frame: WKFrameInfo,
                 type: WKMediaCaptureType) async -> WKPermissionDecision {
        Preferences.shared.currentHomePreferences.alwaysAllowWebRTC ? .grant : .prompt
    }
}
