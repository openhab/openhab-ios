// Copyright (c) 2010-2025 Contributors to the openHAB project
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
    private var activeConfig: ConnectionConfiguration?
    private var hideNavBar = false
    private var activityIndicator: UIActivityIndicatorView!
    private var sseTimer: Timer?
    private var commandQueue: [String] = []
    private var acceptsCommands = false
    private var views: [UUID: WKWebView] = [:]
    // TODO: remove myOhViews when we drop iOS 16 support
    private var myOhViews: [UUID: WKWebView] = [:]

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

    private var logger = Logger(subsystem: "org.openhab.app", category: "OpenHABWebViewController")

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        view.addSubview(webView)
        activityIndicator = UIActivityIndicatorView()
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.style = UIActivityIndicatorView.Style.large

        view.addSubview(activityIndicator)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(hideNavBar, animated: animated)
        navigationController?.navigationBar.prefersLargeTitles = false
        NetworkTracker.shared.$activeConnection
            .receive(on: DispatchQueue.main)
            .sink { activeConnection in
                if let activeConnection {
                    let activeConfiguration = activeConnection.configuration
                    self.logger.info("OpenHABWebViewController openHAB URL = \(activeConfiguration.url)")
                    self.openHABTrackedRootUrl = activeConfiguration.url
                    self.activeConfig = activeConfiguration
                    self.loadWebView(force: false)
                }
            }
            .store(in: &trackerCancellables)

        NetworkTracker.shared.$status
            .receive(on: DispatchQueue.main)
            .sink { status in
                self.logger.info("OpenHABWebViewController tracker status \(status.rawValue)")
                switch status {
                case .connecting:
                    self.showPopupMessage(seconds: 60, title: NSLocalizedString("connecting", comment: ""), message: "", theme: .info)
                case .notConnected:
                    self.pageLoadError(message: NSLocalizedString("network_not_available", comment: ""))
                case .connected:
                    self.hidePopupMessages()
                default: break
                }
            }
            .store(in: &trackerCancellables)
        startTracker()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Show the navigation bar on other view controllers
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        trackerCancellables.removeAll()
    }

    func startTracker() {
        if currentTarget.isEmpty {
            showActivityIndicator(show: true)
        }
    }

    @MainActor
    func loadWebView(force: Bool = false, path: String? = nil) {
        logger.info("loadWebView tracked URL: \(self.activeConfig?.url ?? "") forced \(force ? "true" : "false")")
        guard let activeConfig else { return }
        // TODO: Check whether credentials are truly put into newTarget
        let authStr = "\(activeConfig.username):\(activeConfig.password)"
        let newTarget = "\(activeConfig.url):\(authStr)"

        if !force, currentTarget == newTarget {
            showActivityIndicator(show: false)
            return
        }
        currentTarget = newTarget
        let url = URL(string: activeConfig.url)

        if let modifiedUrl = modifyUrl(orig: url, path: path) {
            acceptsCommands = false
            let request = URLRequest(url: modifiedUrl)
            // TODO: remove this check once iOS 16 is dropped
            let isMyOh = url?.host?.contains("myopenhab.org") ?? false
            // create new (or resuse existing)
            let newWebview = webView(for: Preferences.currentHomePreferences.id, isMyopenhab: isMyOh)
            if newWebview != webView {
                // Detach old instance
                webView.stopLoading()
                webView.navigationDelegate = nil
                webView.uiDelegate = nil
                webView.removeFromSuperview()
                newWebview.navigationDelegate = self
                newWebview.uiDelegate = self
                webView = newWebview
                view.addSubview(newWebview)
            }
            logger.info("Loading URL: \(modifiedUrl)")
            webView.load(request)
        }
    }

    func modifyUrl(orig: URL?, path: String? = nil) -> URL? {
        // better way to clone/copy ?
        guard let urlString = orig?.absoluteString, var url = URL(string: urlString) else { return orig }
        if url.host == "myopenhab.org" {
            url = URL(string: "https://home.myopenhab.org") ?? url
        }
        if let path {
            url = appendPathToURL(baseURL: url, path: path) ?? url
        } else if !Preferences.currentHomePreferences.defaultMainUIPath.isEmpty {
            url = appendPathToURL(baseURL: url, path: Preferences.currentHomePreferences.defaultMainUIPath) ?? url
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

    func setHideNavBar(shouldHide: Bool) {
        hideNavBar = shouldHide
        navigationController?.setNavigationBarHidden(hideNavBar, animated: true)
    }

    func clearExistingPage() {
        logger.info("clearExistingPage")
        setHideNavBar(shouldHide: false)
        // clear out existing page while we load.
        webView.stopLoading()
        webView.evaluateJavaScript("document.body.remove()")
    }

    func pageLoadError(message: String) {
        showActivityIndicator(show: true)
        showPopupMessage(seconds: 60, title: NSLocalizedString("error", comment: ""), message: message, theme: .error)
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

    public func navigateCommand(_ command: String) {
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
                self.logger.error("navigateCommandInternal failed \(error.localizedDescription)")
            } else {
                self.logger.info("navigateCommandInternal Success")
            }
        }
    }

    private func executeQueuedCommands() {
        while !commandQueue.isEmpty {
            let command = commandQueue.removeFirst()
            navigateCommandInternal(command)
        }
    }

    func webView(for id: UUID, isMyopenhab: Bool) -> WKWebView {
        // TODO: remove all iOS < 17 code when we drop iOS 16 support
        if #unavailable(iOS 17) {
            if isMyopenhab, let myExsiting = myOhViews[id] {
                logger.info("Reusing myopenhab webview for id:\(id.uuidString)")
                return myExsiting
            }
        }
        if let existing = views[id] {
            logger.info("Reusing webview for id:\(id.uuidString)")
            return existing
        }
        let config = WKWebViewConfiguration()
        config.processPool = WKProcessPool() // isolates credential cache
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // adds: window.webkit.messageHandlers.xxxx.postMessage to JS env
        config.userContentController.add(self, name: "mainUi")
        config.userContentController.add(self, name: "pathChanged")
        config.userContentController.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))

        // iOS 17 allows Sandboxed profiles, which is fantastic, iOS 16 does not and agressively caches everything
        if #available(iOS 17, *) {
            config.websiteDataStore = WKWebsiteDataStore(forIdentifier: id)
        } else if isMyopenhab {
            // for myopenhab, create a instance that does not persist or share states (private)
            config.websiteDataStore = .nonPersistent()
        }

        let webview = WKWebView(frame: view.bounds, configuration: config)
        webview.navigationDelegate = self
        webview.uiDelegate = self
        // Ensure the newly created webview resizes properly on rotation
        webview.autoresizingMask = [.flexibleWidth, .flexibleHeight]
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

        if #unavailable(iOS 17) {
            if isMyopenhab {
                myOhViews[id] = webview
                return webview
            }
        }
        views[id] = webview
        return webview
    }
}

extension OpenHABWebViewController: WKScriptMessageHandler {
    @MainActor
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        logger.info("WKScriptMessage \(message.name)")
        if message.name == "pathChanged", let newPath = message.body as? String {
            print("path changed to: \(newPath)")
            Preferences.currentWebViewPath = newPath
        }
        if message.name == "mainUi", let callbackName = message.body as? String {
            logger.info("WKScriptMessage \(callbackName)")
            switch callbackName {
            case "exitToApp":
                showSideMenu()
            case "goFullscreen":
                // check to make sure we are actually the top view before hiding the nav button
                if isViewLoaded, view.window != nil {
                    setHideNavBar(shouldHide: true)
                }
            case "sseConnected-true":
                logger.info("WKScriptMessage sseConnected is true")
                hidePopupMessages()
                sseTimer?.invalidate()
                acceptsCommands = true
                executeQueuedCommands()
            case "sseConnected-false":
                logger.info("WKScriptMessage sseConnected is false")
                sseTimer?.invalidate()
                sseTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    Task { @MainActor in
                        self.showPopupMessage(seconds: 20, title: NSLocalizedString("connecting", comment: ""), message: "", theme: .info)
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
        logger.info("decidePolicyFor - url: \(url.absoluteString)")

        if navigationAction.navigationType == .linkActivated {
            await UIApplication.shared.open(url)
            return .cancel // Stop in WebView
        }
        return .allow
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        if let response = navigationResponse.response as? HTTPURLResponse {
            logger.info("navigationResponse: \(response.statusCode)")

            if response.statusCode >= 400 {
                pageLoadError(message: "\(response.statusCode)")
                return .cancel
            }
        }
        return .allow
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
        logger.info("didStartProvisionalNavigation - webView.url: \(String(describing: webView.url?.description))")
        showActivityIndicator(show: true)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: any Error) {
        logger.error("didFail - webView.url: \(String(describing: webView.url?.description))")

        if let urlError = error as? URLError, urlError.code == .cancelled {
            return // Ignore cancelled requests
        }

        pageLoadError(message: error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        logger.info("didFinish - webView.url: \(String(describing: webView.url?.description))")
        showActivityIndicator(show: false)
        hidePopupMessages()
        // watch for URL changes so we can store the last visited path
        if let webviewURL = webView.url {
            let url = URL(string: webviewURL.path, relativeTo: URL(string: openHABTrackedRootUrl))
            if let path = url?.path {
                let string = openHABTrackedRootUrl
                logger.info("navigation change base: \(string) path: \(path)")
                Preferences.currentWebViewPath = path.hasSuffix("/") ? path : path + "/"
            }
        }
    }

    func webView(_ webView: WKWebView, respondTo challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        logger.info("Challenge.protectionSpace.authenticationMethod: \(String(describing: challenge.protectionSpace.authenticationMethod))")

        if let url = modifyUrl(orig: URL(string: openHABTrackedRootUrl)), challenge.protectionSpace.host == url.host {
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                guard let serverTrust = challenge.protectionSpace.serverTrust else {
                    return (.performDefaultHandling, nil)
                }
                let credential = URLCredential(trust: serverTrust)
                return (.useCredential, credential)
            } else {
                if challenge.protectionSpace.authenticationMethod.isAny(of: NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodDefault) {
                    return onReceiveSessionTaskChallenge(with: challenge)
                } else {
                    return await onReceiveSessionChallenge(with: challenge)
                }
            }
        }
        return (.performDefaultHandling, nil)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        logger.warning("webViewWebContentProcessDidTerminate - reloading view")
        reloadView()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
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
        Preferences.currentHomePreferences.alwaysAllowWebRTC ? .grant : .prompt
    }
}
