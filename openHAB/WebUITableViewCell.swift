// Copyright (c) 2010-2025 Contributors to the openHAB project
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
import WebKit

class WebUITableViewCell: GenericUITableViewCell, NoIconDisplayableCell {
    private let logger = Logger(subsystem: "org.openhab.core", category: "WebUITableViewCell")

    private var url: URL?

    private var widgetWebView: WKWebView!

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        selectionStyle = .none
        separatorInset = .zero

        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        widgetWebView = WKWebView(frame: contentView.frame, configuration: configuration)
        contentView.addSubview(widgetWebView)

        widgetWebView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widgetWebView.leftAnchor.constraint(equalTo: contentView.leftAnchor),
            widgetWebView.rightAnchor.constraint(equalTo: contentView.rightAnchor),
            widgetWebView.topAnchor.constraint(equalTo: contentView.topAnchor),
            widgetWebView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        MainActor.assumeIsolated { // See explanation https://www.massicotte.org/awakefromnib
            widgetWebView.navigationDelegate = self
            widgetWebView.uiDelegate = self
        }
    }

    override func displayWidget() {
        // swiftformat:disable redundantSelf
        logger.info("webview loading url \(self.widget.url)")
        // swiftformat:enable redundantSelf

        let urlString = widget.url.lowercased().hasPrefix("http") ? widget.url : Preferences.currentHomePreferences.localConnectionConfig.url + widget.url
        guard url?.absoluteString != urlString else {
            logger.info("webview URL has not changed, abort loading")
            return
        }

        if let url = URL(string: urlString) {
            self.url = url
            let request = URLRequest(url: url)
            widgetWebView?.scrollView.isScrollEnabled = false
            widgetWebView?.scrollView.bounces = false
            widgetWebView?.load(request)
        }
    }

    func setFrame(_ frame: CGRect) {
        logger.info("setFrame")
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
        logger.info("webview started loading with URL: %{PUBLIC}s")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        logger.info("webview finished load with URL: %{PUBLIC}s")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        if let response = navigationResponse.response as? HTTPURLResponse, response.statusCode >= 400 {
            logger.debug("webview failed with status code: %{PUBLIC}i")
            url = nil
        }
        return .allow
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        logger.debug("webview failed with error: %{PUBLIC}s")
        url = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        logger.debug("webview failed with error: %{PUBLIC}s")
        url = nil
    }

    // Signature changed on transfer from completion handler to async / from didRecieve to respondTo
    func webView(_ webView: WKWebView,
                 respondTo challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await onReceiveSessionChallenge(with: challenge)
    }
}

extension WebUITableViewCell: WKUIDelegate {
    func webView(_ webView: WKWebView,
                 decideMediaCapturePermissionsFor origin: WKSecurityOrigin,
                 initiatedBy frame: WKFrameInfo,
                 type: WKMediaCaptureType) async -> WKPermissionDecision {
        .grant
    }
}
