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

/// SwiftUI wrapper for the openHAB WKWebView, driven by OpenHABWebViewModel.
struct OpenHABWebView: UIViewRepresentable {
    @ObservedObject var viewModel: OpenHABWebViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> WKWebView {
        let wv = viewModel.webView
        context.coordinator.attach(to: wv)
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // When the ViewModel swaps the WKWebView (e.g. home change),
        // we need to re-attach the coordinator to the new instance.
        if uiView !== viewModel.webView {
            context.coordinator.detach(from: uiView)
            // SwiftUI will call makeUIView again after this returns a different view,
            // but UIViewRepresentable doesn't support swapping the root view.
            // Instead, we handle this by removing the old and adding the new as a subview.
        }
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        private let viewModel: OpenHABWebViewModel
        private weak var currentWebView: WKWebView?

        init(viewModel: OpenHABWebViewModel) {
            self.viewModel = viewModel
        }

        func attach(to webView: WKWebView) {
            guard currentWebView !== webView else { return }
            if let old = currentWebView {
                detach(from: old)
            }
            webView.navigationDelegate = self
            webView.uiDelegate = self
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "mainUi")
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "pathChanged")
            webView.configuration.userContentController.add(self, name: "mainUi")
            webView.configuration.userContentController.add(self, name: "pathChanged")
            currentWebView = webView
        }

        func detach(from webView: WKWebView) {
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "mainUi")
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "pathChanged")
            if currentWebView === webView {
                currentWebView = nil
            }
        }

        // MARK: - WKScriptMessageHandler

        nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            Task { @MainActor in
                self.handleScriptMessage(message)
            }
        }

        private func handleScriptMessage(_ message: WKScriptMessage) {
            Logger.viewController.info("WKScriptMessage \(message.name)")
            if message.name == "pathChanged", let newPath = message.body as? String {
                Logger.viewController.debug("Path changed to: \(newPath)")
                Preferences.shared.currentWebViewPath = newPath
            }
            if message.name == "mainUi", let callbackName = message.body as? String {
                Logger.viewController.info("WKScriptMessage \(callbackName)")
                switch callbackName {
                case "exitToApp":
                    viewModel.onExitToApp?()
                case "goFullscreen":
                    viewModel.showMenuBar = false
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

            if navigationAction.navigationType == .linkActivated {
                await UIApplication.shared.open(url)
                return .cancel
            }
            return .allow
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
                let svc = SFSafariViewController(url: url)
                UIApplication.shared.firstKeyWindow?.rootViewController?.present(svc, animated: true)
            }
            return nil
        }

        func webView(_ webView: WKWebView,
                     decideMediaCapturePermissionsFor origin: WKSecurityOrigin,
                     initiatedBy frame: WKFrameInfo,
                     type: WKMediaCaptureType) async -> WKPermissionDecision {
            Preferences.shared.currentHomePreferences.alwaysAllowWebRTC ? .grant : .prompt
        }
    }
}

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
        private var cancellable: AnyCancellable?

        init(viewModel: OpenHABWebViewModel) {
            self.viewModel = viewModel
            super.init()
            // Observe webView changes
            cancellable = viewModel.$webView
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newWebView in
                    self?.installWebView(newWebView)
                }
        }

        func installWebView(_ webView: WKWebView) {
            guard webView !== currentWebView else { return }

            if let old = currentWebView {
                old.navigationDelegate = nil
                old.uiDelegate = nil
                old.configuration.userContentController.removeScriptMessageHandler(forName: "mainUi")
                old.configuration.userContentController.removeScriptMessageHandler(forName: "pathChanged")
                old.removeFromSuperview()
            }

            webView.navigationDelegate = self
            webView.uiDelegate = self
            // Remove any existing handlers (a previous coordinator may have registered them)
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "mainUi")
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "pathChanged")
            webView.configuration.userContentController.add(self, name: "mainUi")
            webView.configuration.userContentController.add(self, name: "pathChanged")
            currentWebView = webView

            if let hostView = hostController?.view {
                hostView.addSubview(webView)
                webView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    webView.topAnchor.constraint(equalTo: hostView.topAnchor),
                    webView.bottomAnchor.constraint(equalTo: hostView.bottomAnchor),
                    webView.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
                    webView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor)
                ])
            }
        }

        // MARK: - WKScriptMessageHandler

        nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            Task { @MainActor in
                self.handleScriptMessage(message)
            }
        }

        private func handleScriptMessage(_ message: WKScriptMessage) {
            Logger.viewController.info("WKScriptMessage \(message.name)")
            if message.name == "pathChanged", let newPath = message.body as? String {
                Logger.viewController.debug("Path changed to: \(newPath)")
                Preferences.shared.currentWebViewPath = newPath
            }
            if message.name == "mainUi", let callbackName = message.body as? String {
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
            guard let activeUrl = MainActorNetworkTracker.shared.activeConnection?.configuration.url else {
                return nil
            }
            var knownURLStrings = [activeUrl]
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
                let svc = SFSafariViewController(url: url)
                hostController?.present(svc, animated: true)
            }
            return nil
        }

        func webView(_ webView: WKWebView,
                     decideMediaCapturePermissionsFor origin: WKSecurityOrigin,
                     initiatedBy frame: WKFrameInfo,
                     type: WKMediaCaptureType) async -> WKPermissionDecision {
            Preferences.shared.currentHomePreferences.alwaysAllowWebRTC ? .grant : .prompt
        }
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
