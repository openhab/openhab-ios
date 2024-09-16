// Copyright (c) 2010-2024 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

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
    private var hideNavBar = false
    private var activityIndicator: UIActivityIndicatorView!
    private var observation: NSKeyValueObservation?
    private var sseTimer: Timer?
    private var commandQueue: [String] = []
    private var acceptsCommands = false

    private var js = """
    window.OHApp = {
        exitToApp : function(){
            window.webkit.messageHandlers.Native.postMessage('exitToApp');
        },
        goFullscreen : function(){
            window.webkit.messageHandlers.Native.postMessage('goFullscreen');
        },
        sseConnected : function(connected) {
            window.webkit.messageHandlers.Native.postMessage('sseConnected-' + connected);
        },
        ready : function() {
            window.webkit.messageHandlers.Native.postMessage('ready');
        },
    }
    """

    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

    override open var shouldAutorotate: Bool {
        true
    }

    private lazy var webView: WKWebView = newWebView()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        view.addSubview(webView)
        activityIndicator = UIActivityIndicatorView()
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        if #available(iOS 13.0, *) {
            activityIndicator.style = UIActivityIndicatorView.Style.large
        }
        view.addSubview(activityIndicator)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(hideNavBar, animated: animated)
        navigationController?.navigationBar.prefersLargeTitles = false
        parent?.navigationItem.title = "Main View"
        NetworkTracker.shared.$activeServer
            .receive(on: DispatchQueue.main)
            .sink { activeServer in
                if let activeServer {
                    os_log("OpenHABWebViewController openHAB URL = %{PUBLIC}@", log: .remoteAccess, type: .info, "\(activeServer.url)")
                    self.openHABTrackedRootUrl = activeServer.url
                    self.loadWebView(force: false)
                }
            }
            .store(in: &trackerCancellables)

        NetworkTracker.shared.$status
            .receive(on: DispatchQueue.main)
            .sink { status in
                os_log("OpenHABWebViewController tracker status %{PUBLIC}@", log: .viewCycle, type: .info, status.rawValue)
                switch status {
                case .connecting:
                    self.showPopupMessage(seconds: 60, title: NSLocalizedString("connecting", comment: ""), message: "", theme: .info)
                case .connectionFailed:
                    self.pageLoadError(message: NSLocalizedString("network_not_available", comment: ""))
                case _:
                    break
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
        // OpenHABTracker.shared.multicastDelegate.remove(self)
        trackerCancellables.removeAll()
    }

    func startTracker() {
        if currentTarget == "" {
            showActivityIndicator(show: true)
        }
    }

    func loadWebView(force: Bool = false, path: String? = nil) {
        os_log("loadWebView %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, openHABTrackedRootUrl)

        let authStr = "\(Preferences.username):\(Preferences.password)"
        let newTarget = "\(openHABTrackedRootUrl):\(authStr)"
        if !force, currentTarget == newTarget {
            showActivityIndicator(show: false)
            return
        }

        currentTarget = newTarget
        let url = URL(string: openHABTrackedRootUrl)

        if let modifiedUrl = modifyUrl(orig: url, path: path) {
            let request = URLRequest(url: modifiedUrl)
            clearExistingPage()
            acceptsCommands = false
            webView.load(request)
        }
    }

    func modifyUrl(orig: URL?, path: String? = nil) -> URL? {
        // better way to cone/copy ?
        guard let urlString = orig?.absoluteString, var url = URL(string: urlString) else { return orig }
        if url.host == "myopenhab.org" {
            url = URL(string: "https://home.myopenhab.org") ?? url
        }

        if let path {
            url = appendPathToURL(baseURL: url, path: path) ?? url
        } else if !Preferences.defaultMainUIPath.isEmpty {
            url = appendPathToURL(baseURL: url, path: Preferences.defaultMainUIPath) ?? url
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
        os_log("clearExistingPage - webView.url %{PUBLIC}@", log: .wkwebview, type: .info, String(describing: webView.url?.description))
        setHideNavBar(shouldHide: false)
        // clear out existing page while we load.
        webView.stopLoading()
        webView.evaluateJavaScript("document.body.remove()")
    }

    func pageLoadError(message: String) {
        os_log("pageLoadError - webView.url %{PUBLIC}@ %{PUBLIC}@", log: .wkwebview, type: .info, String(describing: webView.url?.description), message)
        showActivityIndicator(show: false)
        showPopupMessage(seconds: 60, title: NSLocalizedString("error", comment: ""), message: message, theme: .error)
        currentTarget = ""
    }

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
                os_log("navigateCommandInternal failed %{PUBLIC}@", log: .wkwebview, type: .error, error.localizedDescription)
            } else {
                os_log("navigateCommandInternal Success", log: .wkwebview, type: .info)
            }
        }
    }

    private func executeQueuedCommands() {
        while !commandQueue.isEmpty {
            let command = commandQueue.removeFirst()
            navigateCommandInternal(command)
        }
    }

    private func newWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // adds: window.webkit.messageHandlers.xxxx.postMessage to JS env
        config.userContentController.add(self, name: "Native")
        config.userContentController.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))

        let webView = WKWebView(frame: view.bounds, configuration: config)
        // Alow rotation of webview
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.scrollView.bounces = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        // support dark mode and avoid white flashing when loading
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        if UIDevice.current.userInterfaceIdiom == .pad {
            // since ios 13 Safari sets the user agent to desktop mode on iPads so the view renders correctly with larger screens
            webView.customUserAgent = "Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        }
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        // watch for URL changes so we can store the last visited path
        observation = webView.observe(\.url, options: [.new]) { _, _ in
            if let webviewURL = webView.url {
                let url = URL(string: webviewURL.path, relativeTo: URL(string: self.openHABTrackedRootUrl))
                if let path = url?.path {
                    os_log("navigation change base: %{PUBLIC}@ path: %{PUBLIC}@", log: OSLog.default, type: .info, self.openHABTrackedRootUrl, path)
                    // append trailing slash as WebUI/Vue/F7 will try and issue a 302 if the url is navigated to directly, this can be problamatic on myopenHAB
                    self.appData?.currentWebViewPath = path.hasSuffix("/") ? path : path + "/"
                }
            }
        }
        return webView
    }

    deinit {
        observation = nil
    }
}

extension OpenHABWebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        os_log("WKScriptMessage %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, message.name)
        if let callbackName = message.body as? String {
            os_log("WKScriptMessage %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, callbackName)
            switch callbackName {
            case "exitToApp":
                showSideMenu()
            case "goFullscreen":
                // check to make sure we are actually the top view before hiding the nav button
                if isViewLoaded, view.window != nil {
                    setHideNavBar(shouldHide: true)
                }
            case "sseConnected-true":
                os_log("WKScriptMessage sseConnected is true", log: OSLog.remoteAccess, type: .info)
                hidePopupMessages()
                sseTimer?.invalidate()
                acceptsCommands = true
                executeQueuedCommands()
            case "sseConnected-false":
                os_log("WKScriptMessage sseConnected is false", log: OSLog.remoteAccess, type: .info)
                sseTimer?.invalidate()
                sseTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
                    self.showPopupMessage(seconds: 20, title: NSLocalizedString("connecting", comment: ""), message: "", theme: .error)
                    self.acceptsCommands = false
                }
            default: break
            }
        }
    }
}

extension OpenHABWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        var action: WKNavigationActionPolicy?

        defer {
            decisionHandler(action ?? .allow)
        }

        guard let url = navigationAction.request.url else { return }
        os_log("decidePolicyFor - url: %{PUBLIC}@", log: .wkwebview, type: .info, url.absoluteString)

        if navigationAction.navigationType == .linkActivated {
            action = .cancel // Stop in WebView
            UIApplication.shared.open(url)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse {
            dump(response.allHeaderFields)
            os_log("navigationResponse: %{PUBLIC}@", log: .wkwebview, type: .info, String(response.statusCode))
            if response.statusCode >= 400 {
                pageLoadError(message: "\(response.statusCode)")
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        os_log("didStartProvisionalNavigation - webView.url: %{PUBLIC}@", log: .wkwebview, type: .info, String(describing: webView.url?.description))
        showActivityIndicator(show: true)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        os_log("didFail - webView.url %{PUBLIC}@", log: .wkwebview, type: .info, String(describing: webView.url?.description))
        let nserror = error as NSError
        if nserror.code != NSURLErrorCancelled {
            pageLoadError(message: nserror.localizedDescription)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        os_log("didFinish - webView.url %{PUBLIC}@", log: .wkwebview, type: .info, String(describing: webView.url?.description))
        showActivityIndicator(show: false)
        hidePopupMessages()
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        os_log("Challenge.protectionSpace.authtenticationMethod: %{PUBLIC}@", log: .wkwebview, type: .info, String(describing: challenge.protectionSpace.authenticationMethod))

        if let url = modifyUrl(orig: URL(string: openHABTrackedRootUrl)), challenge.protectionSpace.host == url.host {
            // openHABTracker takes care of triggering server trust prompts
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                guard let serverTrust = challenge.protectionSpace.serverTrust else {
                    completionHandler(.performDefaultHandling, nil)
                    return
                }
                let credential = URLCredential(trust: serverTrust)
                DispatchQueue.main.async {
                    completionHandler(.useCredential, credential)
                }
            } else {
                var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
                var credential: URLCredential?
                if challenge.protectionSpace.authenticationMethod.isAny(of: NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodDefault) {
                    (disposition, credential) = onReceiveSessionTaskChallenge(with: challenge)
                } else {
                    (disposition, credential) = onReceiveSessionChallenge(with: challenge)
                }
                completionHandler(disposition, credential)
            }
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        os_log("webViewWebContentProcessDidTerminate  reloading view", log: .wkwebview, type: .info)
        reloadView()
    }

    @available(iOS 15, *)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(Preferences.alwaysAllowWebRTC ? .grant : .prompt)
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
}
