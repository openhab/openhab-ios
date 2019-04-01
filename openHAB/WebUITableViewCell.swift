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

class WebUITableViewCell: GenericUITableViewCell, WKUIDelegate {
    var isLoadingUrl = false
    var isLoaded = false

    @IBOutlet weak var widgetWebView: WKWebView!
    required init?(coder: NSCoder) {
        super.init(coder: coder)

        selectionStyle = .none
        separatorInset = .zero

    }

    override func displayWidget() {
        print("webview loading url \(widget.url)")
        let prefs = UserDefaults.standard
        let openHABUsername = prefs.string(forKey: "username")
        let openHABPassword = prefs.string(forKey: "password")
        let authStr = "\(openHABUsername ?? ""):\(openHABPassword ?? "")"

        guard let loginData = authStr.data(using: String.Encoding.utf8) else {
            return
        }
        let base64LoginString = loginData.base64EncodedString()

        if let url = URL(string: widget.url) {
            var request = URLRequest(url: url)
            request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
            widgetWebView?.scrollView.isScrollEnabled = false
            widgetWebView?.scrollView.bounces = false
            widgetWebView?.load(request)
        }

    }

    func webViewDidStartLoad(_ webView: UIWebView) {
        print("webview started loading")
    }

    func webViewDidFinishLoad(_ webView: UIWebView) {
        print("webview finished load")
    }

    func setFrame(_ frame: CGRect) {
        print("setFrame")
        super.frame = frame
        widgetWebView?.reload()
    }
}
