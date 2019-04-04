//
//  WebUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 19/05/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import WebKit
import os.log

class WebUITableViewCell: GenericUITableViewCell, WKNavigationDelegate {
    var isLoadingUrl = false
    var isLoaded = false

    @IBOutlet weak var widgetWebView: WKWebView!
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        widgetWebView.navigationDelegate = self
    }

    override func displayWidget() {
        os_log("webview loading url %{PUBLIC}@", log: .viewCycle, type: .info, widget.url)
        if let url = URL(string: widget.url), let urlrequest = URLRequest.webUIRequest(url: url) {
            widgetWebView?.scrollView.isScrollEnabled = false
            widgetWebView?.scrollView.bounces = false
            widgetWebView?.load(urlrequest)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        os_log("webview started loading", log: .viewCycle, type: .info)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        os_log("webview finished loading", log: .viewCycle, type: .info)

    }
}
