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

import Kingfisher
import OpenHABCore
import os.log
import SafariServices
import SFSafeSymbols
import SwiftUI

enum AppTab: String, CaseIterable, Hashable {
    case main
    case sitemaps
    case tiles
    case system

    var title: String {
        switch self {
        case .main: "Home"
        case .sitemaps: "Sitemaps"
        case .tiles: "Tiles"
        case .system: "System"
        }
    }

    var systemImage: String {
        switch self {
        case .main: "house"
        case .sitemaps: "map"
        case .tiles: "square.grid.2x2"
        case .system: "gear"
        }
    }
}

struct OpenHABTabRootView: View {
    @StateObject private var appServices = AppServicesViewModel()
    @StateObject private var networkTracker = MainActorNetworkTracker.shared

    @State private var selectedTab: AppTab
    @State private var isDemoMode: Bool
    @State private var enabledTabs: [AppTab]

    @State private var sitemapsResetTrigger = 0
    @State private var tilesResetTrigger = 0
    @State private var systemResetTrigger = 0
    @State private var sitemapNavigationCommand: SitemapNavigationCommand?

    private let webViewController = OpenHABWebViewController()

    private var tabSelectionBinding: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == selectedTab {
                    resetTab(newTab)
                }
                selectedTab = newTab
            }
        )
    }

    init() {
        let saved = Preferences.shared.currentHomePreferences.lastSelectedTab
        _selectedTab = State(initialValue: AppTab(rawValue: saved) ?? .main)
        _isDemoMode = State(initialValue: Preferences.shared.currentHomePreferences.demomode)
        _enabledTabs = State(initialValue: Self.computeEnabledTabs())

        #if DEBUG
        if ProcessInfo.processInfo.environment["UITest"] != nil {
            Preferences.shared.modifyActiveHome { homePreferences in
                homePreferences.demomode = true
            }
        }
        #endif
    }

    private static func computeEnabledTabs() -> [AppTab] {
        let config = Preferences.shared.currentHomePreferences.tabConfiguration ?? TabEntry.defaultConfiguration
        let tabs = config.compactMap { entry -> AppTab? in
            guard entry.enabled || entry.id == AppTab.system.rawValue else { return nil }
            return AppTab(rawValue: entry.id)
        }
        // Ensure system tab is always present
        if !tabs.contains(.system) {
            return tabs + [.system]
        }
        return tabs
    }

    var body: some View {
        TabView(selection: tabSelectionBinding) {
            ForEach(enabledTabs, id: \.self) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    AnyView(tabContentView(for: tab))
                }
            }
        }
        .environmentObject(networkTracker)
        .onChange(of: selectedTab) { oldTab, newTab in
            Preferences.shared.modifyActiveHome { prefs in
                prefs.lastSelectedTab = newTab.rawValue
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("org.openhab.preferences.saved"))) { _ in
            let newTabs = Self.computeEnabledTabs()
            if enabledTabs != newTabs {
                enabledTabs = newTabs
                // If current tab was disabled, switch to first available
                if !enabledTabs.contains(selectedTab) {
                    selectedTab = enabledTabs.first ?? .system
                }
            }
        }
        .onAppear {
            ImageDownloader.default.authenticationChallengeResponder = appServices
            // Switch to sitemaps in demo mode
            if Preferences.shared.currentHomePreferences.demomode {
                selectedTab = .sitemaps
                sitemapNavigationCommand = SitemapNavigationCommand(name: "demo", widgetId: nil)
            }
        }
        .onReceive(appServices.$navigationCommand) { command in
            guard let command else { return }
            handleNavigationCommand(command)
            // Reset the command after handling
            Task { @MainActor in
                appServices.navigationCommand = nil
            }
        }
        // Certificate trust alert
        .alert(
            appServices.certificateAlert?.title ?? "",
            isPresented: Binding(
                get: { appServices.certificateAlert != nil },
                set: { if !$0 { appServices.certificateAlertAction(.deny) } }
            )
        ) {
            Button("Always") {
                appServices.certificateAlertAction(.permitAlways)
            }
            Button("Once") {
                appServices.certificateAlertAction(.permitOnce)
            }
            Button("Deny", role: .cancel) {
                appServices.certificateAlertAction(.deny)
            }
        } message: {
            Text(appServices.certificateAlert?.message ?? "")
        }
        // Crash report alert
        .alert(
            NSLocalizedString("crash_detected", comment: "").capitalized,
            isPresented: $appServices.crashReportAlert
        ) {
            Button(NSLocalizedString("activate", comment: "")) {
                appServices.enableCrashReporting()
            }
            Button(NSLocalizedString("privacy_policy", comment: "")) {
                let vc = SFSafariViewController(url: URL.privacyPolicy)
                vc.configuration.barCollapsingEnabled = true
                UIApplication.shared.firstKeyWindow?.rootViewController?.present(vc, animated: true)
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {
                appServices.deleteCrashReports()
            }
        } message: {
            Text(NSLocalizedString("crash_reporting_info", comment: ""))
        }
    }

    @ViewBuilder
    private func tabContentView(for tab: AppTab) -> some View {
        switch tab {
        case .main:
            MainWebTab(webViewController: webViewController)
                .ignoresSafeArea()
        case .sitemaps:
            SitemapsTab(resetTrigger: sitemapsResetTrigger, navigationCommand: $sitemapNavigationCommand)
        case .tiles:
            TilesTab(resetTrigger: tilesResetTrigger)
        case .system:
            SystemTab(resetTrigger: systemResetTrigger)
        }
    }

    private func resetTab(_ tab: AppTab) {
        switch tab {
        case .main:
            webViewController.loadWebView(force: true)
        case .sitemaps:
            sitemapsResetTrigger += 1
        case .tiles:
            tilesResetTrigger += 1
        case .system:
            systemResetTrigger += 1
        }
    }

    private func handleNavigationCommand(_ command: NavigationCommand) {
        switch command {
        case let .switchToWebView(path):
            selectedTab = .main
            if let path {
                if path.starts(with: "/") {
                    webViewController.loadWebView(force: true, path: path)
                } else {
                    webViewController.navigateCommand(path)
                }
            }
        case let .switchToSitemap(name, widgetId):
            selectedTab = .sitemaps
            sitemapNavigationCommand = SitemapNavigationCommand(name: name, widgetId: widgetId)
        }
    }
}
