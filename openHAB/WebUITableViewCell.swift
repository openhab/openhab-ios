//
//  WebUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 19/05/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import os.log
import WebKit

class WebUITableViewCell: GenericUITableViewCell {
    private var url: URL?

    @IBOutlet private var widgetWebView: WKWebView!

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        selectionStyle = .none
        separatorInset = .zero
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        widgetWebView.navigationDelegate = self
    }

    override func displayWidget() {
        os_log("webview loading url %{PUBLIC}@", log: .default, type: .info, widget.url)

        let urlString = widget.url.lowercased().hasPrefix("http") ? widget.url : Preferences.localUrl + widget.url
        guard url?.absoluteString != urlString else {
            os_log("webview URL has not changed, abort loading", log: .viewCycle, type: .info)
            return
        }

        let authStr = "\(Preferences.username):\(Preferences.password)"

        guard let loginData = authStr.data(using: String.Encoding.utf8) else {
            return
        }
        let base64LoginString = loginData.base64EncodedString()

        if let url = URL(string: urlString) {
            self.url = url
            var request = URLRequest(url: url)
            request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
            widgetWebView?.scrollView.isScrollEnabled = false
            widgetWebView?.scrollView.bounces = false
            widgetWebView?.load(request)
        }
    }

    func setFrame(_ frame: CGRect) {
        os_log("setFrame", log: .viewCycle, type: .info)
        super.frame = frame
        widgetWebView?.reload()
    }
}

extension WebUITableViewCell: GenericCellCacheProtocol {
    func invalidateCache() {
        url = nil
        widgetWebView?.stopLoading()
    }
}

extension WebUITableViewCell: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        os_log("webview started loading with URL: %{PUBLIC}s", log: .viewCycle, type: .info, widget.url)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        os_log("webview finished load with URL: %{PUBLIC}s", log: .viewCycle, type: .info, widget.url)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse, response.statusCode >= 400 {
            os_log("webview failed with status code: %{PUBLIC}i", log: .urlComposition, type: .debug, response.statusCode)
            url = nil
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        os_log("webview failed with error: %{PUBLIC}s", log: .urlComposition, type: .debug, error.localizedDescription)
        url = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        os_log("webview failed with error: %{PUBLIC}s", log: .urlComposition, type: .debug, error.localizedDescription)
        url = nil
    }
}
