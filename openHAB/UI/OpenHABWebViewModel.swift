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
import SwiftMessages
import UIKit
import WebKit

@MainActor
class OpenHABWebViewModel: ObservableObject {
    // MARK: - Published state

    @Published var isLoading = false
    @Published var hideNavigationBar = false
    @Published private(set) var webView: WKWebView

    // MARK: - Internal state (used by Coordinator)

    var acceptsCommands = false
    var commandQueue: [String] = []
    var lastLoadedURL: String?
    /// Callback fired when "exitToApp" is received from JS
    var onExitToApp: (() -> Void)?

    // MARK: - Private state

    private var currentTarget = ""
    private var openHABTrackedRootUrl = ""
    private var activeConnectionInfo: ConnectionInfo?
    private var activeConfig: ConnectionConfiguration? { activeConnectionInfo?.configuration }
    private var sseTimer: Timer?
    private var views: [UUID: WKWebView] = [:]
    private var etagChecker: ETagChecker?
    private var etagCheckerConfigURL: String?
    private var trackerCancellables = Set<AnyCancellable>()

    private let js = """
    (function() {
        // Main UI Callbacks
        window.OHApp = {
            exitToApp : function(){
                window.webkit.messageHandlers.mainUi.postMessage('exitToApp');
            },
            goFullscreen : function(){
                window.webkit.messageHandlers.mainUi.postMessage('goFullscreen');
            },
            sseConnected : function(connected) {
                window.webkit.messageHandlers.mainUi.postMessage('sseConnected-' + connected);
            },
            ready : function() {
                window.webkit.messageHandlers.mainUi.postMessage('ready');
            },
        }

        // Detect Path changes in SPA
        function notifyPathChange() {
            window.webkit.messageHandlers.pathChanged.postMessage(window.location.pathname);
        }

        const originalPushState = history.pushState;
        history.pushState = function() {
            originalPushState.apply(this, arguments);
            notifyPathChange();
        };

        const originalReplaceState = history.replaceState;
        history.replaceState = function() {
            originalReplaceState.apply(this, arguments);
            notifyPathChange();
        };

        window.addEventListener('popstate', notifyPathChange);

        // Notify initial path on load
        notifyPathChange();
    })();
    """

    // MARK: - Init

    init() {
        webView = WKWebView(frame: .zero)
        observeNetworkChanges()
        observeAppLifecycle()
    }

    // MARK: - Network observation

    private func observeNetworkChanges() {
        MainActorNetworkTracker.shared.$activeConnection
            .receive(on: DispatchQueue.main)
            .sink { [weak self] activeConnection in
                guard let self, let activeConnection else { return }
                let activeConfiguration = activeConnection.configuration
                Logger.viewController.info("OpenHABWebView openHAB URL = \(activeConfiguration.url)")
                self.openHABTrackedRootUrl = activeConfiguration.url
                self.activeConnectionInfo = activeConnection
                self.loadWebView(force: false)
            }
            .store(in: &trackerCancellables)
    }

    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Logger.viewController.info("App became active, checking for content updates")
            Task { @MainActor in
                self?.loadWebView(force: false)
            }
        }
    }

    // MARK: - Loading

    func loadWebView(force: Bool = false, path: String? = nil) {
        Logger.viewController.info("loadWebView tracked URL: \(self.activeConfig?.url ?? "") forced \(force ? "true" : "false")")
        guard let activeConfig else { return }
        let authStr = "\(activeConfig.username):\(activeConfig.password)"
        let newTarget = "\(activeConfig.url):\(authStr)"

        if force {
            Task {
                await performLoadWebView(newTarget: newTarget, path: path, force: true)
            }
            return
        }

        Task {
            await loadWebViewWithETagCheck(newTarget: newTarget, path: path)
        }
    }

    private func performLoadWebView(newTarget: String, path: String?, force: Bool) async {
        guard let activeConfig else { return }
        currentTarget = newTarget
        let url = URL(string: activeConfig.url)
        let defaultPath = Preferences.shared.currentHomePreferences.defaultMainUIPath
        guard let modifiedUrl = WebViewURLHelper.resolveWebViewURL(
            baseURL: url,
            proxyURL: activeConnectionInfo?.proxyURL,
            path: path,
            defaultPath: defaultPath
        ) else { return }

        acceptsCommands = false
        var request = URLRequest(url: modifiedUrl)

        if force {
            let dataStore = webView.configuration.websiteDataStore
            let websiteDataTypes: Set<String> = [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]
            let date = Date(timeIntervalSince1970: 0)
            Logger.viewController.info("Force reload: clearing WKWebView cache")
            await dataStore.removeData(ofTypes: websiteDataTypes, modifiedSince: date)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        }

        let isCloudConnection = activeConfig.isCloudConnection
        let newWebview = getOrCreateWebView(for: Preferences.shared.currentHomePreferences.id, isCloudConnection: isCloudConnection)
        if newWebview !== webView {
            webView.stopLoading()
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
            webView = newWebview
        }

        Logger.viewController.info("Loading URL: \(modifiedUrl)")
        isLoading = true
        webView.load(request)
    }

    private func loadWebViewWithETagCheck(newTarget: String, path: String?) async {
        guard let activeConfig,
              let url = URL(string: activeConfig.url) else {
            Logger.viewController.info("ETag check skipped: invalid configuration")
            await performLoadWebView(newTarget: newTarget, path: path, force: false)
            return
        }
        let defaultPath = Preferences.shared.currentHomePreferences.defaultMainUIPath
        guard let fullURL = WebViewURLHelper.resolveWebViewURL(
            baseURL: url,
            proxyURL: activeConnectionInfo?.proxyURL,
            path: path,
            defaultPath: defaultPath
        ) else {
            await performLoadWebView(newTarget: newTarget, path: path, force: false)
            return
        }

        let configKey = "\(activeConfig.url):\(activeConfig.username)"
        if etagChecker == nil || etagCheckerConfigURL != configKey {
            let httpClient = HTTPClient(baseURL: nil, connectionConfiguration: activeConfig)
            etagChecker = ETagChecker(httpClient: httpClient)
            etagCheckerConfigURL = configKey
            Logger.viewController.debug("Created new ETagChecker for config: \(configKey)")
        }

        guard let checker = etagChecker else {
            await performLoadWebView(newTarget: newTarget, path: path, force: false)
            return
        }

        let result = await checker.checkIfChanged(url: fullURL)

        switch result {
        case .unchanged:
            let normalizedTarget = WebViewURLHelper.normalizeForComparison(fullURL.absoluteString, includeBasePath: false)
            let normalizedLoaded = WebViewURLHelper.normalizeForComparison(lastLoadedURL, includeBasePath: false)
            Logger.viewController.debug("ETag unchanged - comparing base URLs: loaded=\(normalizedLoaded ?? "nil") vs target=\(normalizedTarget ?? "nil")")

            if let normalizedTarget, let normalizedLoaded, normalizedLoaded == normalizedTarget {
                Logger.viewController.info("ETag unchanged and same base URL, skipping load")
                currentTarget = newTarget
                isLoading = false
            } else {
                Logger.viewController.info("ETag unchanged but different base URL, loading \(fullURL.absoluteString)")
                await performLoadWebView(newTarget: newTarget, path: path, force: false)
            }

        case .changed:
            Logger.viewController.info("ETag changed, loading \(fullURL.absoluteString)")
            await performLoadWebView(newTarget: newTarget, path: path, force: false)

        case let .failed(error):
            Logger.viewController.info("ETag check failed: \(error.localizedDescription), loading anyway")
            await performLoadWebView(newTarget: newTarget, path: path, force: false)
        }
    }

    // MARK: - WKWebView instance management

    private func getOrCreateWebView(for id: UUID, isCloudConnection: Bool) -> WKWebView {
        if let existing = views[id] {
            Logger.viewController.info("Reusing webview for id:\(id.uuidString)")
            return existing
        }

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // JS bridge is added by the Coordinator when it attaches delegates
        config.userContentController.addUserScript(
            WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        config.websiteDataStore = WKWebsiteDataStore(forIdentifier: id)

        let newWebView = WKWebView(frame: .zero, configuration: config)
        newWebView.scrollView.bounces = false
        newWebView.isOpaque = false
        newWebView.backgroundColor = UIColor.clear
        if UIDevice.current.userInterfaceIdiom == .pad {
            newWebView.customUserAgent = "Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        }
        newWebView.isInspectable = true
        newWebView.scrollView.contentInsetAdjustmentBehavior = .never
        newWebView.scrollView.contentInset = .zero
        newWebView.scrollView.scrollIndicatorInsets = .zero

        views[id] = newWebView
        return newWebView
    }

    // MARK: - Navigation commands

    func navigateCommand(_ command: String) {
        if acceptsCommands {
            navigateCommandInternal(command)
        } else {
            commandQueue.append(command)
        }
    }

    private func navigateCommandInternal(_ command: String) {
        let jsCode = "window.MainUI.handleCommand('\(command)')"
        webView.evaluateJavaScript(jsCode) { _, error in
            if let error {
                Logger.viewController.error("navigateCommandInternal failed \(error.localizedDescription)")
            } else {
                Logger.viewController.info("navigateCommandInternal Success")
            }
        }
    }

    func executeQueuedCommands() {
        while !commandQueue.isEmpty {
            let command = commandQueue.removeFirst()
            navigateCommandInternal(command)
        }
    }

    // MARK: - SSE connection state

    func handleSSEConnected(_ connected: Bool) {
        if connected {
            Logger.viewController.info("WKScriptMessage sseConnected is true")
            sseTimer?.invalidate()
            acceptsCommands = true
            executeQueuedCommands()
        } else {
            Logger.viewController.info("WKScriptMessage sseConnected is false")
            sseTimer?.invalidate()
            sseTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.acceptsCommands = false
                }
            }
        }
    }

    // MARK: - Direct URL loading (for tiles)

    func loadDirectURL(_ url: URL) {
        isLoading = true
        webView.load(URLRequest(url: url))
    }

    // MARK: - Reload

    func reloadView() {
        currentTarget = ""
        webView.stopLoading()
        webView.evaluateJavaScript("document.body.remove()")
        hideNavigationBar = false
        loadWebView(force: true)
    }

    // MARK: - didFinish helpers

    func handleDidFinish() {
        lastLoadedURL = webView.url?.absoluteString
        hideNavigationBar = true
        isLoading = false
        acceptsCommands = true

        if let webviewURL = webView.url {
            let url = URL(string: webviewURL.path, relativeTo: URL(string: openHABTrackedRootUrl))
            if let path = url?.path {
                Logger.viewController.info("navigation change base: \(self.openHABTrackedRootUrl) path: \(path)")
                Preferences.shared.currentWebViewPath = path.hasSuffix("/") ? path : path + "/"
            }
        }

        injectEditorHeightFix()
    }

    private func injectEditorHeightFix() {
        let safeAreaBottom = webView.safeAreaInsets.bottom
        let editorFixJS = """
        (function() {
            if (window.__ohEditorFixInstalled) return;
            window.__ohEditorFixInstalled = true;

            var safeAreaBottom = \(safeAreaBottom);

            function fixScriptEditorHeight() {
                var editor = document.querySelector('.rule-script-editor.v-codemirror');
                if (!editor) return;

                var page = editor.closest('.page');
                if (!page) return;

                var toolbar = page.querySelector('.toolbar');
                if (!toolbar) return;

                var fab = page.querySelector('.fab') || document.querySelector('.fab');
                var fabHeight = 0;
                if (fab) {
                    var fabRect = fab.getBoundingClientRect();
                    fabHeight = fabRect.height || 56;
                }

                var totalBottomPadding = safeAreaBottom;
                if (fab && fabHeight > 0) {
                    totalBottomPadding += fabHeight + 16;
                } else if (fab) {
                    totalBottomPadding += 56 + 16;
                }

                var pageContent = page.querySelector('.page-content');
                if (pageContent) {
                    pageContent.style.paddingBottom = totalBottomPadding + 'px';
                }

                var scrollContainer = editor.querySelector('.cm-scroller') ||
                                     editor.querySelector('.CodeMirror-scroll') ||
                                     editor.querySelector('.cm-content');

                if (scrollContainer && scrollContainer !== editor) {
                    scrollContainer.style.paddingBottom = totalBottomPadding + 'px';
                    scrollContainer.style.overflowY = 'auto';
                    editor.style.marginBottom = totalBottomPadding + 'px';
                } else {
                    editor.style.paddingBottom = totalBottomPadding + 'px';
                    editor.style.marginBottom = totalBottomPadding + 'px';
                }
            }

            new MutationObserver(function(mutations) {
                for (var i = 0; i < mutations.length; i++) {
                    for (var j = 0; j < mutations[i].addedNodes.length; j++) {
                        var n = mutations[i].addedNodes[j];
                        if (n.nodeType === 1 &&
                            ((n.classList && n.classList.contains('rule-script-editor')) ||
                             (n.querySelector && n.querySelector('.rule-script-editor')))) {
                            setTimeout(function() {
                                requestAnimationFrame(fixScriptEditorHeight);
                            }, 100);
                            return;
                        }
                    }
                }
            }).observe(document.body || document.documentElement, { subtree: true, childList: true });

            window.addEventListener('resize', function() {
                setTimeout(function() {
                    requestAnimationFrame(fixScriptEditorHeight);
                }, 100);
            });

            setTimeout(function() {
                fixScriptEditorHeight();
            }, 500);
        })();
        """
        webView.evaluateJavaScript(editorFixJS)
    }

    // MARK: - Authentication

    func resolvedURL() -> URL? {
        guard let url = URL(string: openHABTrackedRootUrl) else { return nil }
        return WebViewURLHelper.resolveWebViewURL(
            baseURL: url,
            proxyURL: activeConnectionInfo?.proxyURL,
            path: nil,
            defaultPath: Preferences.shared.currentHomePreferences.defaultMainUIPath
        )
    }
}
