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
    private var tracker: OpenHABTracker?

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

    private var observation: NSKeyValueObservation?
    private var progressView: UIProgressView!

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
        // webView?.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        // support dark mode and avoid white flashing when loading
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        return webView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        view.addSubview(webView)
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.sizeToFit()
        observation = webView.observe(\.estimatedProgress, options: [.new]) { _, _ in
            self.progressView.progress = Float(self.webView.estimatedProgress)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Hide the navigation bar on the this view controller
        navigationController?.setNavigationBarHidden(true, animated: animated)
        tracker = OpenHABTracker()
        tracker?.delegate = self
        tracker?.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Show the navigation bar on other view controllers
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    func loadWebView(force: Bool = false) {
        os_log("loadWebView %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, appData?.openHABRootUrl ?? "nil")

        let authStr = "\(Preferences.username):\(Preferences.password)"
        let newTarget = "\(appData?.openHABRootUrl ?? ""):\(authStr)"
        if !force, currentTarget == newTarget {
            return
        }
        currentTarget = newTarget
        let url = URL(string: appData?.openHABRootUrl ?? "")
        if let modifiedUrl = modifyUrl(orig: url) {
            let request = URLRequest(url: modifiedUrl)
            // clear out existing page while we load.
            webView.evaluateJavaScript("document.body.remove()")
            webView.load(request)
        }
    }

    func modifyUrl(orig: URL?) -> URL? {
        if orig?.host == "myopenhab.org" {
            return URL(string: "https://home.myopenhab.org")
        }
        return orig
    }

    deinit {
        observation = nil
    }

    override func reloadView() {
        loadWebView(force: true)
    }

    override func viewName() -> String {
        "web"
    }
}

extension OpenHABWebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        os_log("WKScriptMessage %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, message.name)
        if let callbackName = message.body as? String {
            switch callbackName {
            case "exitToApp":
                // _ = navigationController?.popViewController(animated: true)
                guard let menu = SideMenuManager.default.rightMenuNavigationController else { return }

                let drawer = menu.viewControllers.first as? OpenHABDrawerTableViewController
                drawer?.drawerTableType = .withStandardMenuEntries
                drawer?.delegate = appData?.rootViewController
                present(menu, animated: true)
            case "goFullScreen": break
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
        os_log("decidePolicyFor - url: %{PUBLIC}@", log: .urlComposition, type: .info, url.absoluteString)

        if navigationAction.navigationType == .linkActivated {
            action = .cancel // Stop in WebView
            UIApplication.shared.open(url)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse {
            dump(response.allHeaderFields)
            os_log("navigationResponse: %{PUBLIC}@", log: .urlComposition, type: .info, String(response.statusCode))
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        os_log("didStartProvisionalNavigation - webView.url: %{PUBLIC}@", log: .urlComposition, type: .info, String(describing: webView.url?.description))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nserror = error as NSError
        if nserror.code != NSURLErrorCancelled {
            webView.loadHTMLString("Page Not Found", baseURL: URL(string: "https://openHAB.org/"))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        os_log("didFinish - webView.url %{PUBLIC}@", log: .urlComposition, type: .info, String(describing: webView.url?.description))
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let url = modifyUrl(orig: URL(string: appData?.openHABRootUrl ?? "")), challenge.protectionSpace.host == url.host {
            let (disposition, credential) = onReceiveSessionChallenge(URLSession(configuration: .default), challenge)
            completionHandler(disposition, credential)
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
        if let openHABUrl = openHABUrl {
            openHABRootUrl = openHABUrl.absoluteString
        }

        appData?.openHABRootUrl = openHABRootUrl

        NetworkConnection.tracker(openHABRootUrl: openHABRootUrl) { response in
            switch response.result {
            case let .success(data):
                self.loadWebView(force: true)
            case let .failure(error):
                self.openHABTrackingError(error)
                os_log("This is not an openHAB server", log: .remoteAccess, type: .info)
                os_log("On Connecting %{PUBLIC}@ %d", log: .remoteAccess, type: .error, error.localizedDescription, response.response?.statusCode ?? 0)
            }
        }
    }

    func openHABTrackingProgress(_ message: String?) {
        os_log("OpenHABViewController %{PUBLIC}@", log: .viewCycle, type: .info, message ?? "")
        var config = SwiftMessages.Config()
        config.duration = .seconds(seconds: 1.5)
        config.presentationStyle = .bottom

        SwiftMessages.show(config: config) {
            let view = MessageView.viewFromNib(layout: .cardView)
            view.configureTheme(.info)
            view.configureContent(title: NSLocalizedString("connecting", comment: ""), body: message ?? "")
            view.button?.setTitle(NSLocalizedString("dismiss", comment: ""), for: .normal)
            view.buttonTapHandler = { _ in SwiftMessages.hide() }
            return view
        }
    }

    func openHABTrackingError(_ error: Error) {
        os_log("Tracking error: %{PUBLIC}@", log: .viewCycle, type: .info, error.localizedDescription)
        var config = SwiftMessages.Config()
        config.duration = .seconds(seconds: 60)
        config.presentationStyle = .bottom

        SwiftMessages.show(config: config) {
            let view = MessageView.viewFromNib(layout: .cardView)
            // ... configure the view
            view.configureTheme(.error)
            view.configureContent(title: NSLocalizedString("error", comment: ""), body: error.localizedDescription)
            view.button?.setTitle(NSLocalizedString("dismiss", comment: ""), for: .normal)
            view.buttonTapHandler = { _ in SwiftMessages.hide() }
            return view
        }
    }
}
