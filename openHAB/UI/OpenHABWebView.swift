// Copyright (c) 2010-2026 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Combine
import OpenHABCore
import os.log
import SafariServices
import SwiftUI
import WebKit

/// Container view that manages the WKWebView lifecycle with SwiftUI.
/// Handles the case where the ViewModel's webView instance may change (e.g. home switch).
struct OpenHABWebViewContainer: UIViewControllerRepresentable {
    @ObservedObject var viewModel: OpenHABWebViewModel

    func makeCoordinator() -> WebViewContainerCoordinator {
        WebViewContainerCoordinator(viewModel: viewModel)
    }

    func makeUIViewController(context: Context) -> WebViewHostController {
        let controller = WebViewHostController()
        controller.coordinator = context.coordinator
        context.coordinator.hostController = controller
        context.coordinator.installWebView(viewModel.webView)
        return controller
    }

    func updateUIViewController(_ controller: WebViewHostController, context: Context) {
        context.coordinator.installWebView(viewModel.webView)
    }

    @MainActor
    class WebViewContainerCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let viewModel: OpenHABWebViewModel
        weak var hostController: WebViewHostController?
        private weak var currentWebView: WKWebView?
        private var webViewLayoutConstraints: [NSLayoutConstraint] = []
        private var isConfirmingExternalURL = false
        private var externalURLCooldownUntil: Date?
        private var cancellable: AnyCancellable?

        // Capture-phase click interceptor matching develop commit 12b8608c.
        // e.isTrusted filters programmatic .click() / dispatchEvent() calls so only
        // real user gestures reach the message handler.
        private static let externalURLInterceptorScript = WKUserScript(
            source: """
            (function() {
                const nativeSchemes = ['http', 'https', 'about', 'blob', 'data', 'javascript', ''];
                function isCustomScheme(url) {
                    const m = /^([a-z][a-z0-9+\\-.]*):/.exec((url || '').toLowerCase());
                    return m != null && !nativeSchemes.includes(m[1]);
                }
                document.addEventListener('click', function(e) {
                    if (!e.isTrusted) return;
                    let el = e.target;
                    while (el && el.tagName !== 'A') el = el.parentElement;
                    if (el && el.href && isCustomScheme(el.href)) {
                        e.preventDefault();
                        window.webkit.messageHandlers.externalURL.postMessage(el.href);
                    }
                }, true);
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )

        init(viewModel: OpenHABWebViewModel) {
            self.viewModel = viewModel
            super.init()
            // Observe webView changes
            cancellable = viewModel.$webView
                .sink { [weak self] newWebView in
                    self?.installWebView(newWebView)
                }
        }

        func installWebView(_ webView: WKWebView) {
            guard let hostView = hostController?.view else {
                return
            }
            guard webView !== currentWebView else { return }

            if let old = currentWebView {
                old.navigationDelegate = nil
                old.uiDelegate = nil
                old.configuration.userContentController.removeScriptMessageHandler(forName: "mainUi")
                old.configuration.userContentController.removeScriptMessageHandler(forName: "pathChanged")
                old.configuration.userContentController.removeScriptMessageHandler(forName: "externalURL")
                old.removeFromSuperview()
            }

            webView.navigationDelegate = self
            webView.uiDelegate = self
            // Remove any existing handlers (a previous coordinator may have registered them)
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "mainUi")
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "pathChanged")
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "externalURL")
            webView.configuration.userContentController.add(self, name: "mainUi")
            webView.configuration.userContentController.add(self, name: "pathChanged")
            webView.configuration.userContentController.add(self, name: "externalURL")
            webView.configuration.userContentController.addUserScript(Self.externalURLInterceptorScript)
            currentWebView = webView
            
            hostView.addSubview(webView)
            webView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.deactivate(webViewLayoutConstraints)
            webViewLayoutConstraints = [
                webView.topAnchor.constraint(equalTo: hostView.topAnchor),
                webView.bottomAnchor.constraint(equalTo: hostView.bottomAnchor),
                webView.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor)
            ]
            NSLayoutConstraint.activate(webViewLayoutConstraints)
        }

        // MARK: - WKScriptMessageHandler

        nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            Task { @MainActor in
                self.handleScriptMessage(message)
            }
        }

        private func handleScriptMessage(_ message: WKScriptMessage) {
            Logger.viewController.info("WKScriptMessage \(message.name)")
            if message.name == "externalURL",
               let urlString = message.body as? String,
               let url = URL(string: urlString),
               !url.isNativeWebURL {
                Logger.viewController.info("externalURL bridge: \(urlString)")
                Task {
                    if await self.confirmOpenURL(url) {
                        await UIApplication.shared.open(url)
                    }
                }
                return
            }
            if message.name == "pathChanged", let newPath = message.body as? String {
                Logger.viewController.debug("Path changed to: \(newPath)")
                let connection = MainActorNetworkTracker.shared.activeConnection
                let savedPath = relativeWebViewPath(
                    newPath,
                    proxyURL: connection?.proxyURL,
                    rootURLString: connection?.configuration.url ?? ""
                )
                Preferences.shared.currentWebViewPath = savedPath
            }
            if message.name == "mainUi" {
                // Dict body — JS test probe reports (DEBUG builds only)
                #if DEBUG
                if let dict = message.body as? [String: Any],
                   let type = dict["type"] as? String,
                   type == "uiTestReport",
                   let key = dict["key"] as? String,
                   let value = dict["value"] as? String {
                    viewModel.recordUITestReport(key: key, value: value)
                    return
                }
                #endif
                // Dict body — navbar proxy elements
                if let dict = message.body as? [String: Any],
                   let type = dict["type"] as? String,
                   type == "navbarElements",
                   let rawItems = dict["items"] as? [[String: String]] {
                    let items = rawItems.compactMap { raw -> WebNavbarItem? in
                        guard let label = raw["label"], let action = raw["action"] else { return nil }
                        return WebNavbarItem(label: label, jsAction: action, iconBase64: raw["icon"])
                    }
                    let title = dict["title"] as? String ?? ""
                    viewModel.updateNavbarItems(items, title: title)
                    return
                }
                // String body — standard callbacks
                guard let callbackName = message.body as? String else { return }
                Logger.viewController.info("WKScriptMessage \(callbackName)")
                switch callbackName {
                case "exitToApp":
                    viewModel.onExitToApp?()
                case "goFullscreen":
                    viewModel.showMenuBar = false
                case "ready":
                    viewModel.handleReady()
                case "appMenu-hidden":
                    viewModel.handleAppMenuProbe(hidden: true)
                case "appMenu-visible":
                    viewModel.handleAppMenuProbe(hidden: false)
                case "sseConnected-true":
                    viewModel.handleSSEConnected(true)
                case "sseConnected-false":
                    viewModel.handleSSEConnected(false)
                default:
                    break
                }
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .allow }
            Logger.viewController.info("decidePolicyFor - url: \(url.absoluteString)")
            if !url.isNativeWebURL {
                // JS-triggered custom-scheme navigations (e.g. window.location = 'shortcuts://...')
                // arrive here; anchor taps are caught by the injected JS handler first.
                if await confirmOpenURL(url) {
                    await UIApplication.shared.open(url)
                }
                return .cancel
            }
            if navigationAction.navigationType == .linkActivated {
                if let rewritten = rewriteToActiveConnection(url) {
                    Logger.viewController.info("decidePolicyFor - loading in-app (rewritten): \(rewritten.absoluteString)")
                    webView.load(URLRequest(url: rewritten))
                    return .cancel
                }
                await UIApplication.shared.open(url)
                return .cancel
            }
            return .allow
        }

        /// Rewrites `url` to use the active connection's origin when the URL's host+port
        /// matches any configured home server connection.  Returns `nil` if no match is found,
        /// meaning the link should be opened externally.
        private func rewriteToActiveConnection(_ url: URL) -> URL? {
            guard let activeConnection = MainActorNetworkTracker.shared.activeConnection else {
                return nil
            }
            let activeUrl = activeConnection.configuration.url
            var knownURLStrings = [activeUrl]
            // Include the proxy URL so cloud-proxied links are recognised as in-app navigations
            // and rewritten to the active connection, matching develop commit ec0d0957 (#1244).
            if let proxyURLString = activeConnection.proxyURL?.absoluteString {
                knownURLStrings.append(proxyURLString)
            }
            for home in Preferences.shared.storedHomes.values {
                knownURLStrings.append(home.localConnectionConfig.url)
                knownURLStrings.append(home.remoteConnectionConfig.url)
            }
            return WebViewURLHelper.rewriteToActiveConnection(url, knownBaseURLStrings: knownURLStrings, activeBaseURLString: activeUrl)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
            if let response = navigationResponse.response as? HTTPURLResponse {
                Logger.viewController.info("navigationResponse: \(response.statusCode)")
                if response.statusCode >= 400 {
                    viewModel.isLoading = true
                    return .cancel
                }
            }
            return .allow
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
            Logger.viewController.info("didStartProvisionalNavigation - webView.url: \(String(describing: webView.url?.description))")
            viewModel.isLoading = true
            viewModel.handleNavigationStart()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: any Error) {
            Logger.viewController.error("didFail - webView.url: \(String(describing: webView.url?.description))")
            if let urlError = error as? URLError, urlError.code == .cancelled {
                return
            }
            viewModel.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Logger.viewController.info("didFinish - webView.url: \(String(describing: webView.url?.description))")
            viewModel.handleDidFinish()
        }

        func webView(_ webView: WKWebView, respondTo challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            Logger.viewController.info("Challenge.protectionSpace.authenticationMethod: \(String(describing: challenge.protectionSpace.authenticationMethod))")

            if let url = viewModel.resolvedURL(), challenge.protectionSpace.host == url.host {
                if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                    guard let serverTrust = challenge.protectionSpace.serverTrust else {
                        return (.performDefaultHandling, nil)
                    }
                    return (.useCredential, URLCredential(trust: serverTrust))
                } else {
                    if challenge.protectionSpace.authenticationMethod.isAny(of: NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodDefault) {
                        return await onReceiveSessionTaskChallenge(with: challenge)
                    } else {
                        return await onReceiveSessionChallenge(with: challenge)
                    }
                }
            }
            return (.performDefaultHandling, nil)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            Logger.viewController.warning("webViewWebContentProcessDidTerminate - reloading view")
            viewModel.reloadView()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
            viewModel.reloadView()
        }

        // MARK: - WKUIDelegate

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            let schemes = ["http", "https"]
            if navigationAction.targetFrame == nil,
               let url = navigationAction.request.url,
               let scheme = url.scheme,
               schemes.contains(scheme) {
                Task { await UIApplication.shared.open(url) }
            }
            return nil
        }

        func webView(_ webView: WKWebView,
                     decideMediaCapturePermissionsFor origin: WKSecurityOrigin,
                     initiatedBy frame: WKFrameInfo,
                     type: WKMediaCaptureType) async -> WKPermissionDecision {
            Preferences.shared.currentHomePreferences.alwaysAllowWebRTC ? .grant : .prompt
        }

        // MARK: - External URL confirmation

        // Shows a native confirmation alert before opening a custom URL scheme, matching
        // develop commit 12b8608c. Guards against re-entrancy, missing window, and script
        // spam (3-second cooldown after each resolution).
        private func confirmOpenURL(_ url: URL) async -> Bool {
            let now = Date()
            guard !isConfirmingExternalURL,
                  hostController?.presentedViewController == nil,
                  hostController?.viewIfLoaded?.window != nil,
                  externalURLCooldownUntil.map({ now >= $0 }) ?? true else {
                return false
            }
            guard let hostController else { return false }
            isConfirmingExternalURL = true
            defer { isConfirmingExternalURL = false }

            let confirmed = await withCheckedContinuation { continuation in
                let alert = UIAlertController(title: url.absoluteString, message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel) { _ in
                    continuation.resume(returning: false)
                })
                alert.addAction(UIAlertAction(title: String(localized: "Open"), style: .default) { _ in
                    continuation.resume(returning: true)
                })
                hostController.present(alert, animated: true)
            }
            externalURLCooldownUntil = Date(timeIntervalSinceNow: 3)
            return confirmed
        }
    }
}

private extension URL {
    /// Returns true for schemes that WKWebView can load natively, matching develop commit 12b8608c.
    var isNativeWebURL: Bool {
        guard let scheme = scheme?.lowercased() else { return true }
        return ["http", "https", "about", "blob", "data", "javascript"].contains(scheme)
    }

    /// RFC 6454 origin: scheme + host + port, with default ports (80/443) omitted.
    /// Added in develop commit ec0d0957 (#1244).
    var webOrigin: String? {
        guard let scheme = scheme?.lowercased(), let host else { return nil }
        let defaultPort = scheme == "https" ? 443 : scheme == "http" ? 80 : nil
        let portSuffix = (port != nil && port != defaultPort) ? ":\(port!)" : ""
        return "\(scheme)://\(host)\(portSuffix)"
    }
}

/// Minimal UIViewController that hosts a WKWebView managed by the Coordinator.
class WebViewHostController: UIViewController {
    var coordinator: OpenHABWebViewContainer.WebViewContainerCoordinator?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }
}
