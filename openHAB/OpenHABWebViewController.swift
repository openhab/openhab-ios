// Copyright (c) 2010-2020 Contributors to the openHAB project
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
    @IBOutlet var webView: WKWebView?
    private var currentTarget = ""

    private var js = """
    window.$ohwebui.$f7.on('routeChanged', function (newRoute, prevRoute) {
        window.webkit.messageHandlers.events.postMessage(newRoute.path)
    })
    """
    override open var shouldAutorotate: Bool {
        true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // adds: window.webkit.messageHandlers.xxxx.postMessage to JS env
        config.userContentController.add(self, name: "events")
        config.userContentController.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        webView = WKWebView(frame: view.bounds, configuration: config)
        // Alow rotation of webview
        webView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // webView?.scrollView.isScrollEnabled = false
        webView?.scrollView.bounces = false
        webView?.navigationDelegate = self
        view.addSubview(webView!)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Hide the navigation bar on the this view controller
        navigationController?.setNavigationBarHidden(true, animated: animated)
        loadWebView(force: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Show the navigation bar on other view controllers
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // Equivalent of shouldStartLoadWithRequest:
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

    // Equivalent of webViewDidStartLoad:
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("didStartProvisionalNavigation - webView.url: \(String(describing: webView.url?.description))")
    }

    // Equivalent of didFailLoadWithError:
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nserror = error as NSError
        if nserror.code != NSURLErrorCancelled {
            webView.loadHTMLString("Page Not Found", baseURL: URL(string: "https://openHAB.org/"))
        }
    }

    // Equivalent of webViewDidFinishLoad:
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("didFinish - webView.url: \(String(describing: webView.url?.description))")
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
//        if let data = message.body as? [String : String], let name = data["name"], let email = data["email"] {
//            showUser(email: email, name: name)
//        }
        print("WKScriptMessage \(message.name) \(message.body)")
    }

    func loadWebView(force: Bool = false) {
        let urlString = Preferences.localUrl
//        let urlString = "http://192.168.90.167:8080"
        let authStr = "\(Preferences.username):\(Preferences.password)"
        let newTarget = "\(urlString):\(authStr)"
        if !force, currentTarget == newTarget {
            return
        }
        currentTarget = newTarget
        guard let loginData = authStr.data(using: String.Encoding.utf8) else {
            return
        }
        let base64LoginString = loginData.base64EncodedString()
        if let url = URL(string: urlString) {
            var request = URLRequest(url: url)
            request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
            webView?.load(request)
        }
    }
}
