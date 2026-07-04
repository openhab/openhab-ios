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

import FirebaseCrashlytics
import OpenHABCore
import os
import SwiftUI

struct SettingsView: View {
    @StateObject private var networkTracker = MainActorNetworkTracker.shared

    @State private var settingsDemomode = false
    @State private var settingsIdleOff = true
    @State private var settingsRealTimeSliders = true
    @State private var settingsShowSearchField = true
    @State private var settingsSendCrashReports = false
    @State private var settingsSitemapDiagnosticsLogging = false
    @State private var settingsIconType: IconType = .svg
    @State private var settingsSortSitemapsBy: SortSitemapsOrder = .label
    @State private var settingsDefaultMainUIPath = ""
    @State private var settingsAlwaysAllowWebRTC = true
    @State private var settingsSitemapForWatch = ""
    @State private var settingsSitemapForCarPlay = ""

    @State private var sitemaps: [OpenHABSitemap] = []
    @State private var settingsLocalConnectionConfiguration = ConnectionConfiguration(url: "", username: "", password: "")
    @State private var settingsRemoteConnectionConfiguration = ConnectionConfiguration(url: "", username: "", password: "")
    @State private var settingsHomeName = ""
    @State private var viewAppearedOnce = false
    @State private var settingsSSECommandItem = ""
    @State private var showLocalNetworkAlert = false
    @State private var loadedLocalURL = ""
    @State private var localTestedOKURL = ""

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            ConnectionSettingsView(
                settingsDemomode: $settingsDemomode,
                localConnectionConfiguration: $settingsLocalConnectionConfiguration,
                remoteConnectionConfiguration: $settingsRemoteConnectionConfiguration,
                localTestedOKURL: $localTestedOKURL
            )

            ApplicationSettingsView(
                settingsIdleOff: $settingsIdleOff,
                settingsSSECommandItem: $settingsSSECommandItem
            )

            MainUISettingsView(
                settingsAlwaysAllowWebRTC: $settingsAlwaysAllowWebRTC,
                settingsDefaultMainUIPath: $settingsDefaultMainUIPath
            )

            SitemapSettingsView(
                settingsRealTimeSliders: $settingsRealTimeSliders,
                settingsShowSearchField: $settingsShowSearchField,
                settingsIconType: $settingsIconType,
                settingsSortSitemapsBy: $settingsSortSitemapsBy,
                settingsSitemapForWatch: $settingsSitemapForWatch,
                settingsSitemapForCarPlay: $settingsSitemapForCarPlay,
                sitemaps: $sitemaps
            )

            DebugSettingsView(
                settingsSendCrashReports: $settingsSendCrashReports,
                settingsSitemapDiagnosticsLogging: $settingsSitemapDiagnosticsLogging
            )

            AboutSettingsView()
        }
        .formStyle(.grouped)
        .navigationBarBackButtonHidden(true)
        .navigationTitle("\(settingsHomeName) Settings")
        .alert("Local Network Access Required", isPresented: $showLocalNetworkAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
                dismiss()
            }
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("To connect to your local openHAB server, please allow Local Network access when prompted. If you previously denied it, enable it in Settings → Privacy & Security → Local Network.")
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Save") {
                    saveSettings()
                    NotificationCenter.default.post(name: NSNotification.Name("org.openhab.preferences.saved"), object: nil)
                    if !settingsDemomode,
                       !settingsLocalConnectionConfiguration.url.isEmpty,
                       settingsLocalConnectionConfiguration.url != loadedLocalURL,
                       settingsLocalConnectionConfiguration.url != localTestedOKURL {
                        showLocalNetworkAlert = true
                    } else {
                        dismiss()
                    }
                }
            }
            ToolbarItemGroup(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .task {
            guard !viewAppearedOnce else { return }
            viewAppearedOnce = true
            loadSettings()
        }
        .task(id: networkTracker.activeConnection) {
            guard let activeConnection = networkTracker.activeConnection else { return }
            await updateSitemaps(activeConfiguration: activeConnection.configuration)
        }
    }

    private func updateSitemaps(activeConfiguration: ConnectionConfiguration) async {
        do {
            let openAPIService = try OpenAPIService(connectionConfiguration: activeConfiguration)

            sitemaps = try await openAPIService.openHABSitemaps()
            if sitemaps.last?.name == "_default", sitemaps.count > 1 {
                sitemaps = Array(sitemaps.dropLast())
            }

            // Sort the sitemaps according to Settings selection.
            switch SortSitemapsOrder(rawValue: Preferences.shared.currentHomePreferences.sortSitemapsBy) ?? .label {
            case .label: sitemaps.sort { $0.label < $1.label }
            case .name: sitemaps.sort { $0.name < $1.name }
            }
        } catch {
            Logger.settingsView.error("\(error.localizedDescription)")
            sitemaps = []
        }
    }

    private func loadSettings() {
        #if !DEBUG
        Logger.settingsView.debug("Loading Settings")
        #endif
        settingsDemomode = Preferences.shared.currentHomePreferences.demomode
        settingsIdleOff = Preferences.shared.idleOff
        settingsRealTimeSliders = Preferences.shared.currentHomePreferences.realTimeSliders
        settingsShowSearchField = Preferences.shared.applicationPreferences.showSearchField
        settingsSitemapDiagnosticsLogging = Preferences.shared.applicationPreferences.sitemapDiagnosticsLogging
        settingsSendCrashReports = Preferences.shared.sendCrashReports
        settingsIconType = IconType(rawValue: Preferences.shared.currentHomePreferences.iconType) ?? .svg
        settingsSortSitemapsBy = SortSitemapsOrder(rawValue: Preferences.shared.currentHomePreferences.sortSitemapsBy) ?? .label
        settingsDefaultMainUIPath = Preferences.shared.currentHomePreferences.defaultMainUIPath
        settingsAlwaysAllowWebRTC = Preferences.shared.currentHomePreferences.alwaysAllowWebRTC
        settingsSitemapForWatch = Preferences.shared.currentHomePreferences.sitemapForWatch
        settingsSitemapForCarPlay = Preferences.shared.currentHomePreferences.sitemapForCarPlay
        settingsLocalConnectionConfiguration = Preferences.shared.currentHomePreferences.localConnectionConfig
        settingsRemoteConnectionConfiguration = Preferences.shared.currentHomePreferences.remoteConnectionConfig
        loadedLocalURL = Preferences.shared.currentHomePreferences.localConnectionConfig.url
        settingsHomeName = Preferences.shared.currentHomePreferences.homeName
        settingsSSECommandItem = Preferences.shared.currentHomePreferences.sseCommandItem
    }

    func saveSettings() {
        Preferences.shared.modifyActiveHome { @MainActor homePreferences in
            homePreferences.demomode = settingsDemomode
            homePreferences.realTimeSliders = settingsRealTimeSliders
            homePreferences.iconType = settingsIconType.rawValue
            homePreferences.sortSitemapsBy = settingsSortSitemapsBy.rawValue
            homePreferences.defaultMainUIPath = settingsDefaultMainUIPath
            homePreferences.alwaysAllowWebRTC = settingsAlwaysAllowWebRTC
            homePreferences.sitemapForWatch = settingsSitemapForWatch
            homePreferences.sitemapForWatchLabel = sitemaps.first { $0.name == settingsSitemapForWatch }?.label ?? "unknown"
            homePreferences.sitemapForCarPlay = settingsSitemapForCarPlay
            homePreferences.localConnectionConfig = settingsLocalConnectionConfiguration
            homePreferences.remoteConnectionConfig = settingsRemoteConnectionConfiguration
            homePreferences.sseCommandItem = settingsSSECommandItem
        }
        Preferences.shared.idleOff = settingsIdleOff
        Preferences.shared.sendCrashReports = settingsSendCrashReports

        Preferences.shared.modifyApplicationPreferences { @MainActor applicationPreferences in
            applicationPreferences.showSearchField = settingsShowSearchField
            applicationPreferences.sitemapDiagnosticsLogging = settingsSitemapDiagnosticsLogging
        }

        // Apply global UI changes immediately (status bar visibility)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first?.rootViewController?
            .setNeedsStatusBarAppearanceUpdate()
    }
}

extension UIApplication {
    var firstKeyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .first?.keyWindow
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
