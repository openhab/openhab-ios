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
    @StateObject private var appServices = AppServicesViewModel()
    @StateObject private var menuData = MenuDataService()
    @StateObject private var webViewModel = OpenHABWebViewModel()
    @State private var menuPresented = false
    @State private var currentContent: ContentType = .webview
    @State private var showSettings = false
    @State private var showNotifications = false
    @State private var showHomeSelection = false
    @State private var isDemoMode = false
    @State private var sitemapResetID = UUID()

    enum ContentType: Equatable {
        case webview
        case sitemap(name: String)
        case tile(url: String)
    }

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
            ImageDownloader.default.authenticationChallengeResponder = appServices
            isDemoMode = Preferences.shared.currentHomePreferences.demomode
            switchToSavedView()
            setupExitToApp()
        }
        .onReceive(appServices.$navigationCommand.compactMap { $0 }) { command in
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
            appServices.certificateAlert?.title ?? "",
            isPresented: Binding(
                get: { appServices.certificateAlert != nil },
                set: { if !$0 { appServices.certificateAlert = nil } }
            )
        ) {
            Button("Always") { appServices.certificateAlertAction(.permitAlways) }
            Button("Once") { appServices.certificateAlertAction(.permitOnce) }
            Button("Deny", role: .cancel) { appServices.certificateAlertAction(.deny) }
        } message: {
            Text(appServices.certificateAlert?.message ?? "")
        }
        .alert("Crash Report", isPresented: $appServices.crashReportAlert) {
            Button("Send") { appServices.enableCrashReporting() }
            Button("Don't Send", role: .cancel) { appServices.deleteCrashReports() }
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
                .id(sitemapResetID)
        case .tile:
            OpenHABWebViewContainer(viewModel: webViewModel)
                .ignoresSafeArea()
        }
    }

    private func switchToSavedView() {
        if Preferences.shared.currentHomePreferences.demomode {
            switchContent(to: .sitemap(name: "demo"))
        } else {
            let defaultView = Preferences.shared.currentHomePreferences.defaultView
            let defaultSitemap = Preferences.shared.currentHomePreferences.defaultSitemap
            if defaultView == "sitemap" {
                switchContent(to: .sitemap(name: defaultSitemap))
            } else {
                switchContent(to: .webview)
            }
        }
    }

    private func switchContent(to newContent: ContentType) {
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
            switchContent(to: .sitemap(name: name))
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
            switchContent(to: .sitemap(name: name))
        }
        appServices.navigationCommand = nil
    }

    // MARK: - Helpers

    private var isWebOrTileContent: Bool {
        switch currentContent {
        case .webview, .tile: return true
        case .sitemap: return false
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
            switchContent(to: .tile(url: resolvedUrl.absoluteString))
        }
    }

    private func openSafari(url: URL) {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        let svc = SFSafariViewController(url: url, configuration: config)
        UIApplication.shared.firstKeyWindow?.rootViewController?.present(svc, animated: true)
    }
}
