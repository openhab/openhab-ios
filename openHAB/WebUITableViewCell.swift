//
//  WebUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 19/05/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

class WebUITableViewCell: GenericUITableViewCell, UIWebViewDelegate {
    var widgetWebView: UIWebView?
    var isLoadingUrl = false
    var isLoaded = false

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        selectionStyle = UITableViewCell.SelectionStyle.none
        separatorInset = UIEdgeInsets.zero
        widgetWebView = viewWithTag(1001) as? UIWebView
    
    }

    override func displayWidget() {
        print("webview loading url \(widget.url)")
        let prefs = UserDefaults.standard
        let openHABUsername = prefs.value(forKey: "username") as? String
        let openHABPassword = prefs.value(forKey: "password") as? String
        let authStr = "\(openHABUsername ?? ""):\(openHABPassword ?? "")"
        let authData: Data? = authStr.data(using: .ascii)
        let authValue = "Basic \(authData?.base64EncodedString(options: []) ?? "")"
        var mutableRequest: NSMutableURLRequest? = nil
        if let url = URL(string: widget.url) {
            mutableRequest = NSMutableURLRequest(url: url)
        }
        mutableRequest?.setValue(authValue, forHTTPHeaderField: "Authorization")
        let nsrequest = mutableRequest as? URLRequest
        widgetWebView?.scrollView.isScrollEnabled = false
        widgetWebView?.scrollView.bounces = false
        if let nsrequest = nsrequest {
            widgetWebView?.loadRequest(nsrequest)
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
