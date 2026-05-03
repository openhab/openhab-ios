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
import CommonUI
import Kingfisher
import OpenHABCore
import os.log
import SafariServices
import SFSafeSymbols
import SwiftUI

struct OpenHABRootView: View {
    @StateObject private var networkService = NetworkConnectionService()
    @StateObject private var notificationService = NotificationActionService()
    @StateObject private var pushService = PushRegistrationService()
    @StateObject private var crashService = CrashReportService()
    @StateObject private var menuData = MenuDataService()
    @StateObject private var webViewModel = OpenHABWebViewModel()
    @State private var menuPresented = false
    @State private var currentContent: TargetController = .webview
    @State private var currentViewTitle: String = ""
    @State private var activeNetworkConnection: ConnectionInfo? = MainActorNetworkTracker.shared.activeConnection
    @State private var showNotifications = false
    @State private var showHomeSelection = false
    @State private var isDemoMode = false
    @State private var sitemapResetID = UUID()

    var body: some View {
        ZStack {
            contentView

            // Toolbar menu overlay
            ToolbarMenu(
                isPresented: $menuPresented,
                menuData: menuData,
                onSelect: { target in handleMenuSelection(target) },
                onReload: { webViewModel.reloadView() }
            )
        }
        .onAppear {
            ImageDownloader.default.authenticationChallengeResponder = networkService
            isDemoMode = Preferences.shared.currentHomePreferences.demomode
            switchToSavedView()
            setupExitToApp()
        }
        .onReceive(notificationService.$navigationCommand.compactMap { $0 }) { command in
            handleNavigationCommand(command)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("org.openhab.preferences.saved"))) { _ in
            menuData.refresh()
            webViewModel.reloadView()
        }
        .task {
            for await connection in MainActorNetworkTracker.shared.$activeConnection.values {
                activeNetworkConnection = connection
            }
        }
        .sheet(isPresented: $showNotifications) {
            NavigationView { NotificationsView() }
        }
        .sheet(isPresented: $showHomeSelection) {
            NavigationView { HomeSelectionView() }
        }
        .alert(
            networkService.certificateAlert?.title ?? "",
            isPresented: Binding(
                get: { networkService.certificateAlert != nil },
                set: { if !$0 { networkService.certificateAlert = nil } }
            )
        ) {
            Button("Always") { networkService.certificateAlertAction(.permitAlways) }
            Button("Once") { networkService.certificateAlertAction(.permitOnce) }
            Button("Deny", role: .cancel) { networkService.certificateAlertAction(.deny) }
        } message: {
            Text(networkService.certificateAlert?.message ?? "")
        }
        .alert("Crash Report", isPresented: $crashService.crashReportAlert) {
            Button("Send") { crashService.enableCrashReporting() }
            Button("Don't Send", role: .cancel) { crashService.deleteCrashReports() }
        } message: {
            Text("The app crashed during the previous session. Would you like to send a crash report?")
        }
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.environment["UITest"] != nil {
                Preferences.shared.modifyActiveHome { $0.demomode = true }
            }
        }
        #endif
    }

    // MARK: - Content switching

    @ViewBuilder
    private var contentView: some View {
        switch currentContent {
        case .webview:
            ZStack(alignment: .top) {
                OpenHABWebViewContainer(viewModel: webViewModel)
                    .background(.clear)
                menuBar
            }
            .onAppear { webViewModel.triggerAppMenuProbe() }
        case let .sitemap(name):
            SitemapNavigationView(onShowSideMenu: { menuPresented = true })
                .id("\(name)-\(sitemapResetID)")
        case .tile:
            VStack(spacing: 0) {
                menuBar
                OpenHABWebViewContainer(viewModel: webViewModel)
            }
        case .notifications, .homeSelection, .browser:
            preconditionFailure("Modal/transient targets must never become currentContent")
        }
    }

    @ViewBuilder
    private var menuBar: some View {
        let isWebviewMode: Bool = {
            if case .webview = currentContent { return true }
            return false
        }()

        let barTitle: String = {
            if isWebviewMode { return webViewModel.navbarTitle }
            if case .tile = currentContent { return currentViewTitle }
            return ""
        }()

        HStack {
            // Left side: proxied navbar items (webview mode with items available),
            // or connection-status indicator as fallback.
            Group {
                if isWebviewMode, !webViewModel.navbarItems.isEmpty {
                    ForEach(webViewModel.navbarItems) { item in
                        Button {
                            webViewModel.evaluateJS(item.jsAction)
                        } label: {
                            if let uiImg = item.iconImage {
                                Image(uiImage: uiImg)
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)
                            } else {
                                Text(item.label)
                            }
                        }
                        .ohMinimumHitTarget()
                    }
                } else if isWebviewMode, activeNetworkConnection == nil {
                    HStack(spacing: 4) {
                        Image(systemSymbol: .wifiExclamationmark)
                        Text("Offline")
                            .ohTextToken(.secondary)
                        Button { webViewModel.reloadView() } label: {
                            Image(systemSymbol: .arrowClockwise)
                        }
                    }
                    .foregroundStyle(.secondary)
                } else if webViewModel.isLoading {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Connecting")
                            .ohTextToken(.secondary)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.leading)

            Spacer()

            Group {
                if #available(iOS 26, *) {
                    Button {
                        menuPresented = true
                    } label: {
                        Image(systemSymbol: .line3Horizontal)
                            .font(.title)
                    }
                    .buttonStyle(.glass)
                    .ohMinimumHitTarget()
                    .accessibilityIdentifier("HamburgerButton")
                    .accessibilityLabel("Menu")
                    .padding(.trailing)
                } else {
                    Button {
                        menuPresented = true
                    } label: {
                        Image(systemSymbol: .line3Horizontal)
                            .font(.title)
                    }
                    .ohMinimumHitTarget()
                    .accessibilityIdentifier("HamburgerButton")
                    .accessibilityLabel("Menu")
                    .padding(.trailing)
                }
            }
            .scaleEffect(menuPresented ? 3.0 : 1.0, anchor: .topTrailing)
            .opacity(menuPresented ? 0.0 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: menuPresented)
        }
        .frame(height: 44)
        .overlay {
            if !barTitle.isEmpty {
                Text(barTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: 200)
                    .allowsHitTesting(false)
            }
        }
        .background(
            isWebviewMode
                ? AnyShapeStyle(.bar)
                : AnyShapeStyle(Color(.systemBackground)),
            ignoresSafeAreaEdges: .top
        )
    }

    private func switchToSavedView() {
        if Preferences.shared.currentHomePreferences.demomode {
            switchContent(to: .sitemap("demo"))
        } else {
            let defaultView = Preferences.shared.currentHomePreferences.defaultView
            let defaultSitemap = Preferences.shared.currentHomePreferences.defaultSitemap
            if defaultView == "sitemap" {
                switchContent(to: .sitemap(defaultSitemap))
            } else {
                switchContent(to: .webview)
            }
        }
    }

    private func switchContent(to newContent: TargetController) {
        if currentContent == newContent {
            // Tapped same item — reload
            switch newContent {
            case .webview:
                webViewModel.reloadView()
            case .sitemap:
                sitemapResetID = UUID() // pop to root by recreating the NavigationStack
            case let .tile(url):
                if let url = URL(string: url) {
                    webViewModel.loadTilePage(url)
                }
            default:
                break // modal/transient targets never reach switchContent
            }
        } else {
            let wasShowingTile: Bool
            if case .tile = currentContent { wasShowingTile = true } else { wasShowingTile = false }

            currentContent = newContent

            switch newContent {
            case .webview:
                if wasShowingTile { webViewModel.reloadView() }
            case .sitemap:
                break
            case let .tile(url):
                if let url = URL(string: url) {
                    webViewModel.loadTilePage(url)
                }
            default:
                break // modal/transient targets never reach switchContent
            }

            if !Preferences.shared.currentHomePreferences.demomode {
                let viewName: String
                switch newContent {
                case .webview: viewName = "web"
                case .sitemap: viewName = "sitemap"
                case .tile: viewName = "web" // treat tile as web for persistence
                default: return // modal/transient targets never reach switchContent
                }
                Preferences.shared.modifyActiveHome { $0.defaultView = viewName }
            }
        }
    }

    // MARK: - Menu handling

    private func handleMenuSelection(_ target: TargetController) {
        switch target {
        case .webview:
            currentViewTitle = ""
            switchContent(to: .webview)
        case let .sitemap(name):
            Preferences.shared.modifyActiveHome { $0.defaultSitemap = name }
            switchContent(to: .sitemap(name))
        case .notifications:
            showNotifications = true
        case .homeSelection:
            showHomeSelection = true
        case let .tile(urlString):
            currentViewTitle = menuData.label(forURL: urlString)
            switchToTile(urlString)
        case let .browser(urlString):
            if let url = URL(string: urlString) {
                openSafari(url: url)
            }
        }
    }

    // MARK: - Navigation command handling

    private func handleNavigationCommand(_ command: NavigationCommand) {
        switch command {
        case let .switchToWebView(path):
            if currentContent != .webview {
                switchContent(to: .webview)
            }
            if let path {
                if path.starts(with: "/") {
                    webViewModel.loadWebView(force: true, path: path)
                } else {
                    webViewModel.navigateCommand(path)
                }
            }
        case let .switchToSitemap(name, _):
            switchContent(to: .sitemap(name))
        }
        notificationService.navigationCommand = nil
    }

    // MARK: - Helpers

    private func setupExitToApp() {
        webViewModel.onExitToApp = {
            menuPresented = true
        }
    }

    private func switchToTile(_ urlString: String) {
        guard !urlString.isEmpty else { return }
        let resolvedUrl: URL?
        if urlString.hasPrefix("http") || urlString.hasPrefix("https") {
            resolvedUrl = URL(string: urlString)
        } else {
            guard let rootUrl = MainActorNetworkTracker.shared.activeConnection?.configuration.url else { return }
            resolvedUrl = Endpoint.resource(openHABRootUrl: rootUrl, path: urlString.prepare()).url
        }
        if let resolvedUrl {
            switchContent(to: .tile(resolvedUrl.absoluteString))
        }
    }

    private func openSafari(url: URL) {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        let svc = SFSafariViewController(url: url, configuration: config)
        UIApplication.shared.firstKeyWindow?.rootViewController?.present(svc, animated: true)
    }
}
