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
import SwiftMessages
import WebKit

@MainActor
@Observable
class OpenHABWebViewModel {
    private var currentTarget = ""
    private var openHABTrackedRootUrl = ""
    private var activeConnectionInfo: ConnectionInfo?
    private var activeConfig: ConnectionConfiguration? { activeConnectionInfo?.configuration }
    
    var page = WebPage()
    var pageConfiguration = WebPage.Configuration()
    var hideNavigationBar = false
    var isLoading = false
    var commandQueue: [String] = []
    var acceptsCommands = false
    var etagChecker: ETagChecker?
    var etagCheckerConfigURL: String?
    var lastLoadedURL: String?
    var currentPath: String = ""
    
    private var trackerCancellables = Set<AnyCancellable>()
    private var sseTimer: Timer?
    
    private var js = """
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
    
    init() {
        setupWebPage()
        observeNetworkChanges()
        observeAppLifecycle()
    }
    
    private func setupWebPage() {
        pageConfiguration.loadsSubresources = true
        pageConfiguration.defaultNavigationPreferences.allowsContentJavaScript = true
        
        // Use default data store for persistence
        pageConfiguration.websiteDataStore = .default()
        
        page = WebPage(configuration: pageConfiguration, navigationDecider: WebNavigationDecider(viewModel: self))
        
        // Set custom user agent for iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            page.customUserAgent = "Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        }
    }
    
    private func observeNetworkChanges() {
        MainActorNetworkTracker.shared.$activeConnection
            .receive(on: DispatchQueue.main)
            .sink { [weak self] activeConnection in
                guard let self else { return }
                if let activeConnection {
                    let activeConfiguration = activeConnection.configuration
                    Logger.viewController.info("OpenHABWebView openHAB URL = \(activeConfiguration.url)")
                    self.openHABTrackedRootUrl = activeConfiguration.url
                    self.activeConnectionInfo = activeConnection
                    Task {
                        await self.loadWebView(force: false)
                    }
                }
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
            Task {
                await self?.loadWebView(force: false)
            }
        }
    }
    
    func loadWebView(force: Bool = false, path: String? = nil) async {
        Logger.viewController.info("loadWebView tracked URL: \(self.activeConfig?.url ?? "") forced \(force ? "true" : "false")")
        guard let activeConfig else { return }
        
        let authStr = "\(activeConfig.username):\(activeConfig.password)"
        let newTarget = "\(activeConfig.url):\(authStr)"
        
        if force {
            await performLoadWebView(newTarget: newTarget, path: path, force: true)
            return
        }
        
        await loadWebViewWithETagCheck(newTarget: newTarget, path: path)
    }
    
    private func performLoadWebView(newTarget: String, path: String?, force: Bool) async {
        guard let activeConfig else { return }
        currentTarget = newTarget
        
        guard let url = URL(string: activeConfig.url),
              let modifiedUrl = await modifyUrl(orig: url, path: path) else { return }
        
        acceptsCommands = false
        var request = URLRequest(url: modifiedUrl)
        
        if force {
            // Clear cache for force reload
            let dataStore = pageConfiguration.websiteDataStore
            let websiteDataTypes: Set<String> = [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]
            let date = Date(timeIntervalSince1970: 0)
            
            Logger.viewController.info("Force reload: clearing WebView cache")
            await dataStore.removeData(ofTypes: websiteDataTypes, modifiedSince: date)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        }
        
        Logger.viewController.info("Loading URL: \(modifiedUrl)")
        isLoading = true
        let _ = page.load(request)
    }
    
    private func loadWebViewWithETagCheck(newTarget: String, path: String?) async {
        guard let activeConfig,
              let url = URL(string: activeConfig.url),
              let fullURL = await modifyUrl(orig: url, path: path) else {
            Logger.viewController.info("ETag check skipped: invalid configuration")
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
            let normalizedTarget = normalizeURLForComparison(fullURL.absoluteString, includeBasePath: false)
            let normalizedLoaded = normalizeURLForComparison(lastLoadedURL, includeBasePath: false)
            
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
    
    private func normalizeURLForComparison(_ urlString: String?, includeBasePath: Bool = false) -> String? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        
        if !includeBasePath {
            components?.path = ""
            components?.query = nil
        }
        
        guard var normalized = components?.url?.absoluteString else { return nil }
        
        if normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }
        
        return normalized
    }
    
    func modifyUrl(orig: URL?, path: String? = nil) async -> URL? {
        guard let urlString = orig?.absoluteString, var url = URL(string: urlString) else { return orig }
        
        if let proxyURL = activeConnectionInfo?.proxyURL {
            url = proxyURL
        }
        
        if let path {
            url = appendPathToURL(baseURL: url, path: path) ?? url
        } else if await !Preferences.shared.currentHomePreferences.defaultMainUIPath.isEmpty {
            url = appendPathToURL(baseURL: url, path: await Preferences.shared.currentHomePreferences.defaultMainUIPath) ?? url
        }
        
        return url
    }
    
    func appendPathToURL(baseURL: URL, path: String) -> URL? {
        guard var urlComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        if let questionMarkRange = path.range(of: "?") {
            let pathComponent = String(path[..<questionMarkRange.lowerBound])
            let queryComponent = String(path[questionMarkRange.upperBound...])
            urlComponents.path = (urlComponents.path as NSString).appendingPathComponent(pathComponent)
            urlComponents.query = queryComponent
        } else {
            urlComponents.path = (urlComponents.path as NSString).appendingPathComponent(path)
        }
        
        return urlComponents.url
    }
    
    func navigateCommand(_ command: String) {
        if acceptsCommands {
            navigateCommandInternal(command)
        } else {
            commandQueue.append(command)
        }
    }
    
    private func navigateCommandInternal(_ command: String) {
        let jsCode = "window.MainUI.handleCommand('\(command)')"
        Task {
            do {
                let _ = try await page.callJavaScript(jsCode)
                Logger.viewController.info("navigateCommandInternal Success")
            } catch {
                Logger.viewController.error("navigateCommandInternal failed \(error.localizedDescription)")
            }
        }
    }
    
    func executeQueuedCommands() {
        while !commandQueue.isEmpty {
            let command = commandQueue.removeFirst()
            navigateCommandInternal(command)
        }
    }
    
    func handleSSEConnected(_ connected: Bool) {
        if connected {
            Logger.viewController.info("SSE Connected")
            sseTimer?.invalidate()
            acceptsCommands = true
            executeQueuedCommands()
        } else {
            Logger.viewController.info("SSE Disconnected")
            sseTimer?.invalidate()
            sseTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.acceptsCommands = false
                }
            }
        }
    }
    
    func handlePathChanged(_ newPath: String) {
        Logger.viewController.debug("Path changed to: \(newPath)")
        currentPath = newPath
        Task {
            let normalizedPath = newPath.hasSuffix("/") ? newPath : newPath + "/"
            await Preferences.shared.setCurrentWebViewPath(normalizedPath)
        }
    }
    
    func reloadView() {
        currentTarget = ""
        page.stopLoading()
        Task {
            await loadWebView(force: true)
        }
    }
}

// Navigation Decider for handling navigation events
struct WebNavigationDecider: WebPage.NavigationDeciding {
    weak var viewModel: OpenHABWebViewModel?
    
    @MainActor
    func decidePolicyFor(navigationAction: WebPage.NavigationAction) async -> WebPage.NavigationPreferences? {
        guard let url = navigationAction.request.url else { return nil }
        Logger.viewController.info("decidePolicyFor - url: \(url.absoluteString)")
        
        // Handle link activation (open in Safari)
        if navigationAction.navigationType == .linkActivated {
            await UIApplication.shared.open(url)
            return nil // Cancel navigation in WebView
        }
        
        // Allow navigation with JavaScript enabled
        var preferences = WebPage.NavigationPreferences()
        preferences.allowsContentJavaScript = true
        return preferences
    }
    
    @MainActor
    func decidePolicyFor(navigationResponse: WebPage.NavigationResponse) async -> Bool {
        if let response = navigationResponse.response as? HTTPURLResponse {
            Logger.viewController.info("navigationResponse: \(response.statusCode)")
            return response.statusCode < 400
        }
        return true
    }
}

struct OpenHABWebView: View {
    @State var viewModel: OpenHABWebViewModel
    
    var body: some View {
        ZStack {
            WebView(viewModel.page)
                .webViewBackForwardNavigationGestures(.disabled)
                .webViewMagnificationGestures(.enabled)
                .webViewTextSelection(.enabled)
                //.webViewContentBackground(.color(.systemBackground))
            
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            }
        }
        .toolbar(viewModel.hideNavigationBar ? .hidden : .visible, for: .navigationBar)
        .onChange(of: viewModel.page.isLoading) { _, newValue in
            handleLoadingStateChange(newValue)
        }
        .onAppear {
            Task {
                await viewModel.loadWebView(force: false)
            }
        }
    }
    
    private func handleLoadingStateChange(_ isLoading: Bool) {
        viewModel.isLoading = isLoading
        
        if isLoading {
            viewModel.hideNavigationBar = false
        } else {
            viewModel.hideNavigationBar = true
            viewModel.acceptsCommands = true
            
            // Track the loaded URL
            if let url = viewModel.page.url {
                viewModel.lastLoadedURL = url.absoluteString
                viewModel.handlePathChanged(url.path)
            }
        }
    }
}
