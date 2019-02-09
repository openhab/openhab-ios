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

        selectionStyle = UITableViewCell.SelectionStyle.none
        separatorInset = UIEdgeInsets.zero
        let webConfiguration = WKWebViewConfiguration()

        widgetWebView = WKWebView(frame: .zero, configuration: webConfiguration)
        widgetWebView.uiDelegate = self

    }

    override func displayWidget() {
        print("webview loading url \(widget.url)")
        let prefs = UserDefaults.standard
        let openHABUsername = prefs.value(forKey: "username") as? String
        let openHABPassword = prefs.value(forKey: "password") as? String
        let authStr = "\(openHABUsername ?? ""):\(openHABPassword ?? "")"
        let authData: Data? = authStr.data(using: .ascii)
        let authValue = "Basic \(authData?.base64EncodedString(options: []) ?? "")"
        var mutableRequest: NSMutableURLRequest?
        if let url = URL(string: widget.url) {
            mutableRequest = NSMutableURLRequest(url: url)
        }
        mutableRequest?.setValue(authValue, forHTTPHeaderField: "Authorization")
        let nsrequest = mutableRequest as? URLRequest
        widgetWebView?.scrollView.isScrollEnabled = false
        widgetWebView?.scrollView.bounces = false
        if let nsrequest = nsrequest {
            widgetWebView?.load(nsrequest)
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
