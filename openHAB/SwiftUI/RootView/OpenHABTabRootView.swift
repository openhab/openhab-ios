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
}

struct OpenHABTabRootView: View {
    @StateObject private var appServices = AppServicesViewModel()
    @StateObject private var networkTracker = MainActorNetworkTracker.shared

    @State private var selectedTab: AppTab
    @State private var isDemoMode: Bool
    @State private var sitemapsTab = SitemapsTab()

    private let webViewController = OpenHABWebViewController()

    init() {
        let saved = Preferences.shared.currentHomePreferences.lastSelectedTab
        _selectedTab = State(initialValue: AppTab(rawValue: saved) ?? .main)
        _isDemoMode = State(initialValue: Preferences.shared.currentHomePreferences.demomode)

        #if DEBUG
        if ProcessInfo.processInfo.environment["UITest"] != nil {
            Preferences.shared.modifyActiveHome { homePreferences in
                homePreferences.demomode = true
            }
        }
        #endif
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: AppTab.main) {
                MainWebTab(webViewController: webViewController)
                    .ignoresSafeArea()
            }

            Tab("Sitemaps", systemImage: "map", value: AppTab.sitemaps) {
                sitemapsTab
            }

            Tab("Tiles", systemImage: "square.grid.2x2", value: AppTab.tiles) {
                TilesTab()
            }

            Tab("System", systemImage: "gear", value: AppTab.system) {
                SystemTab()
            }
        }
        .environmentObject(networkTracker)
        .onChange(of: selectedTab) { oldTab, newTab in
            Preferences.shared.modifyActiveHome { prefs in
                prefs.lastSelectedTab = newTab.rawValue
            }
        }
        .onAppear {
            ImageDownloader.default.authenticationChallengeResponder = appServices
            // Switch to sitemaps in demo mode
            if Preferences.shared.currentHomePreferences.demomode {
                selectedTab = .sitemaps
                sitemapsTab.navigateToSitemap(name: "demo", widgetId: nil)
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
            sitemapsTab.navigateToSitemap(name: name, widgetId: widgetId)
        }
    }
}
