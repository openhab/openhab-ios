// Copyright (c) 2010-2021 Contributors to the openHAB project
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
import SafariServices
import UIKit
import WebKit

class OpenHABWebViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    private var currentTarget = ""

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
    var openHABRootUrl = ""
    override open var shouldAutorotate: Bool {
        true
    }

    @IBOutlet private var webView: WKWebView?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // adds: window.webkit.messageHandlers.xxxx.postMessage to JS env
        config.userContentController.add(self, name: "Native")
        config.userContentController.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        webView = WKWebView(frame: view.bounds, configuration: config)
        // Alow rotation of webview
        webView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // webView?.scrollView.isScrollEnabled = false
        webView?.scrollView.bounces = false
        webView?.navigationDelegate = self
        // support dark mode and avoid white flashing when loading
        webView?.isOpaque = false
        webView?.backgroundColor = UIColor.clear
        view.addSubview(webView!)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Hide the navigation bar on the this view controller
        navigationController?.setNavigationBarHidden(true, animated: animated)
        loadWebView(force: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Show the navigation bar on other view controllers
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        var action: WKNavigationActionPolicy?

        defer {
            decisionHandler(action ?? .allow)
        }

        guard let url = navigationAction.request.url else { return }
        print("decidePolicyFor - url: \(url)")

        if navigationAction.navigationType == .linkActivated {
            action = .cancel // Stop in WebView
            UIApplication.shared.open(url)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse {
            dump(response.allHeaderFields)
            print("navigationResponse: \(String(response.statusCode))")
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("didStartProvisionalNavigation - webView.url: \(String(describing: webView.url?.description))")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nserror = error as NSError
        if nserror.code != NSURLErrorCancelled {
            webView.loadHTMLString("Page Not Found", baseURL: URL(string: "https://openHAB.org/"))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("didFinish - webView.url: \(String(describing: webView.url?.description))")
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let credential = URLCredential(
            user: Preferences.username,
            password: Preferences.password,
            persistence: .forSession
        )
        completionHandler(.useCredential, credential)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print("WKScriptMessage \(message.name) \(message.body)")
        if let callbackName = message.body as? String {
            switch callbackName {
            case "exitToApp":
                _ = navigationController?.popViewController(animated: true)
            case "goFullScreen": break
            default: break
            }
        }
    }

    func loadWebView(force: Bool = false) {
        let authStr = "\(Preferences.username):\(Preferences.password)"
        let newTarget = "\(openHABRootUrl):\(authStr)"
        if !force, currentTarget == newTarget {
            return
        }
        currentTarget = newTarget
        let url = URL(string: openHABRootUrl)
        if let modifiedUrl = modifyUrl(orig: url) {
            let request = URLRequest(url: modifiedUrl)
            // clear out existing page while we load.
            webView?.evaluateJavaScript("document.body.remove()")
            webView?.load(request)
        }
    }

    func modifyUrl(orig: URL?) -> URL? {
        if orig?.host == "myopenhab.org" {
            return URL(string: "https://home.myopenhab.org")
        }
        return orig
    }
}
