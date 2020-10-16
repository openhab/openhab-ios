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

import Foundation
import OpenHABCore
import WebKit

class HabPanelViewController: UIViewController, WKUIDelegate {
    var openHABRootUrl: String {
        AppDelegate.appDelegate.appData.openHABRootUrl
    }

    let webView = WKWebView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
    }

    fileprivate func setupWebView() {
        webView.uiDelegate = self
        DispatchQueue.main.async {
            self.webView.load(Endpoint.habpanel(rootUrl: self.openHABRootUrl))
        }
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        webView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    }
}

extension WKWebView {
    func load(_ endpoint: Endpoint) {
        if let url = endpoint.url {
            let request = URLRequest(url: url)
            load(request)
        }
    }
}
