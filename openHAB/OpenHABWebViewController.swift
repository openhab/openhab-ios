// Copyright (c) 2010-2022 Contributors to the openHAB project
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
    private var tracker: OpenHABTracker?
    private var activityIndicator: UIActivityIndicatorView!
    private var observation: NSKeyValueObservation?

    // https://developer.apple.com/documentation/webkit/wkscriptmessagehandler?preferredLanguage=occ
    private var js = """
    window.OHApp = {
        exitToApp : function(){
            window.webkit.messageHandlers.Native.postMessage('exitToApp');
        },
        goFullscreen : function(){
            window.webkit.messageHandlers.Native.postMessage('goFullscreen');
        }
    }
    """

    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

    override open var shouldAutorotate: Bool {
        true
    }

    private lazy var webView: WKWebView = {
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
        // watch for URL changes so we can store the last visited path
        observation = webView.observe(\.url, options: [.new]) { _, _ in
            if let webviewURL = webView.url {
                let url = URL(string: webviewURL.path, relativeTo: URL(string: self.openHABTrackedRootUrl))
                if let path = url?.path {
                    os_log("navigation change base: %{PUBLIC}@ path: %{PUBLIC}@", log: OSLog.default, type: .info, self.openHABTrackedRootUrl, path)
                    self.appData?.currentWebViewPath = path
                }
            }
        }
        return webView
    }()

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
        startTracker()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Show the navigation bar on other view controllers
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    func startTracker() {
        if currentTarget == "" {
            showActivityIndicator(show: true)
        }
        tracker = OpenHABTracker()
        tracker?.delegate = self
        tracker?.start()
    }

    func loadWebView(force: Bool = false) {
        os_log("loadWebView %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, openHABTrackedRootUrl)

        let authStr = "\(Preferences.username):\(Preferences.password)"
        let newTarget = "\(openHABTrackedRootUrl):\(authStr)"
        if !force, currentTarget == newTarget {
            showActivityIndicator(show: false)
            return
        }

        currentTarget = newTarget
        let url = URL(string: openHABTrackedRootUrl)

        if let modifiedUrl = modifyUrl(orig: url) {
            let request = URLRequest(url: modifiedUrl)
            clearExistingPage()
            webView.load(request)
        }
    }

    func modifyUrl(orig: URL?) -> URL? {
        // better way to cone/copy ?
        guard let urlString = orig?.absoluteString, var url = URL(string: urlString) else { return orig }
        if url.host == "myopenhab.org" {
            url = URL(string: "https://home.myopenhab.org") ?? url
        }

        if !Preferences.defaultMainUIPath.isEmpty {
            url.appendPathComponent(Preferences.defaultMainUIPath)
        }
        return url
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
        setHideNavBar(shouldHide: false)
        // clear out existing page while we load.
        webView.evaluateJavaScript("document.body.remove()")
    }

    func pageLoadError(message: String) {
        os_log("pageLoadError - webView.url %{PUBLIC}@ %{PUBLIC}@", log: .wkwebview, type: .info, String(describing: webView.url?.description), message)
        showActivityIndicator(show: false)
        // webView.loadHTMLString("Page Not Found", baseURL: URL(string: "https://openHAB.org/"))
        showPopupMessage(seconds: 60, title: NSLocalizedString("error", comment: ""), message: message, theme: .error)
        currentTarget = ""
    }

    override func reloadView() {
        currentTarget = ""
        clearExistingPage()
        startTracker()
    }

    override func viewName() -> String {
        "web"
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
                completionHandler(.useCredential, credential)
            } else {
                var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
                var credential: URLCredential?
                if challenge.protectionSpace.authenticationMethod.isAny(of: NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodDefault) {
                    (disposition, credential) = onReceiveSessionTaskChallenge(URLSession(configuration: .default), URLSessionDataTask(), challenge)
                } else {
                    (disposition, credential) = onReceiveSessionChallenge(URLSession(configuration: .default), challenge)
                }
                completionHandler(disposition, credential)
            }
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
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

// MARK: - OpenHABTrackerDelegate

extension OpenHABWebViewController: OpenHABTrackerDelegate {
    func openHABTracked(_ openHABUrl: URL?) {
        os_log("OpenHABWebViewController openHAB URL =  %{PUBLIC}@", log: .remoteAccess, type: .error, "\(openHABUrl!)")

        var openHABRootUrl = ""
        if let openHABUrl {
            openHABRootUrl = openHABUrl.absoluteString
        }
        appData?.openHABRootUrl = openHABRootUrl

        NetworkConnection.tracker(openHABRootUrl: openHABRootUrl) { response in
            switch response.result {
            case let .success(data):
                do {
                    let serverProperties = try data.decoded(as: OpenHABServerProperties.self)
                    os_log("openHAB version %@", log: .remoteAccess, type: .info, serverProperties.version)
                    self.openHABTrackedRootUrl = openHABRootUrl
                    self.appData?.openHABRootUrl = openHABRootUrl
                    self.loadWebView(force: false)
                } catch {
                    // testing for OH 1.x
                    let str = String(decoding: data, as: UTF8.self)
                    if str.hasPrefix("<?xml") {
                        self.appData?.openHABVersion = 1
                        self.showPopupMessage(seconds: 2, title: NSLocalizedString("select_sitemap", comment: ""), message: "", theme: .info)
                        self.showSideMenu()
                        return
                    }
                    os_log("Could not decode response as JSON, %{PUBLIC}@ %d", log: .notifications, type: .error, error.localizedDescription, response.response?.statusCode ?? 0)
                    self.openHABTrackingError(error)
                }
            case let .failure(error):
                self.openHABTrackingError(error)
                os_log("This is not an openHAB server", log: .remoteAccess, type: .info)
                os_log("On Connecting %{PUBLIC}@ %d", log: .remoteAccess, type: .error, error.localizedDescription, response.response?.statusCode ?? 0)
            }
        }
    }

    func openHABTrackingProgress(_ message: String?) {
        os_log("OpenHABViewController %{PUBLIC}@", log: .viewCycle, type: .info, message ?? "")
        showPopupMessage(seconds: 1.5, title: NSLocalizedString("connecting", comment: ""), message: message ?? "", theme: .info)
    }

    func openHABTrackingError(_ error: Error) {
        os_log("Tracking error: %{PUBLIC}@", log: .viewCycle, type: .info, error.localizedDescription)
        pageLoadError(message: error.localizedDescription)
    }
}
