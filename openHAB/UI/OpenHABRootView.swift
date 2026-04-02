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
import Kingfisher
import OpenHABCore
import os.log
import SafariServices
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
    @State private var showSettings = false
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
                isWebViewActive: isWebOrTileContent
            ) { target in
                handleMenuSelection(target)
            }
        }
        .overlay(alignment: .topTrailing) {
            // Only show floating button for webview/tile (which have no NavigationStack toolbar).
            // SitemapNavigationView gets the button via its onShowSideMenu closure.
            if isWebOrTileContent, !menuPresented {
                ToolbarMenuButton(isMenuPresented: $menuPresented)
                    .padding(.trailing, 16)
                    .padding(.top, 8)
            }
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
        .sheet(isPresented: $showSettings) {
            NavigationView { SettingsView() }
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
            OpenHABWebViewContainer(viewModel: webViewModel)
                .ignoresSafeArea()
        case let .sitemap(name):
            SitemapNavigationView(onShowSideMenu: { menuPresented = true })
                .id("\(name)-\(sitemapResetID)")
        case .tile:
            OpenHABWebViewContainer(viewModel: webViewModel)
                .ignoresSafeArea()
        case .settings, .notifications, .homeSelection, .browser:
            preconditionFailure("Modal/transient targets must never become currentContent")
        }
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
                    webViewModel.loadDirectURL(url)
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
                    webViewModel.loadDirectURL(url)
                }
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
            switchContent(to: .webview)
        case let .sitemap(name):
            Preferences.shared.modifyActiveHome { $0.defaultSitemap = name }
            switchContent(to: .sitemap(name))
        case .settings:
            showSettings = true
        case .notifications:
            showNotifications = true
        case .homeSelection:
            showHomeSelection = true
        case let .tile(urlString):
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

    private var isWebOrTileContent: Bool {
        switch currentContent {
        case .webview, .tile: return true
        case .sitemap: return false
        default: return false
        }
    }

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
