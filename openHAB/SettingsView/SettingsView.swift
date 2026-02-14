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

    private struct SettingsSnapshot: Equatable {
        var demomode: Bool
        var idleOff: Bool
        var realTimeSliders: Bool
        var showSearchField: Bool
        var sendCrashReports: Bool
        var iconType: IconType
        var sortSitemapsBy: SortSitemapsOrder
        var defaultMainUIPath: String
        var alwaysAllowWebRTC: Bool
        var sitemapForWatch: String
        var localConnectionConfig: ConnectionConfiguration
        var remoteConnectionConfig: ConnectionConfiguration
        var homeName: String
        var sseCommandItem: String
    }

struct SettingsView: View {
    @State private var settingsDemomode = false
    @State private var settingsIdleOff = true
    @State private var settingsRealTimeSliders = true
    @State private var settingsShowSearchField = true
    @State private var settingsSendCrashReports = false
    @State private var settingsIconType: IconType = .svg
    @State private var settingsSortSitemapsBy: SortSitemapsOrder = .label
    @State private var settingsDefaultMainUIPath = ""
    @State private var settingsAlwaysAllowWebRTC = true
    @State private var settingsSitemapForWatch = ""

    @State private var sitemaps: [OpenHABSitemap] = []
    @State private var settingsLocalConnectionConfiguration = ConnectionConfiguration(url: "", username: "", password: "")
    @State private var settingsRemoteConnectionConfiguration = ConnectionConfiguration(url: "", username: "", password: "")
    @State private var settingsHomeName = ""
    @State private var viewAppearedOnce = false
    @State private var settingsSSECommandItem = ""

    @State private var initialSnapshot: SettingsSnapshot?
    @State private var isDirty = false

    @Environment(\.dismiss) private var dismiss

    private var currentSnapshot: SettingsSnapshot {
        SettingsSnapshot(
            demomode: settingsDemomode,
            idleOff: settingsIdleOff,
            realTimeSliders: settingsRealTimeSliders,
            showSearchField: settingsShowSearchField,
            sendCrashReports: settingsSendCrashReports,
            iconType: settingsIconType,
            sortSitemapsBy: settingsSortSitemapsBy,
            defaultMainUIPath: settingsDefaultMainUIPath,
            alwaysAllowWebRTC: settingsAlwaysAllowWebRTC,
            sitemapForWatch: settingsSitemapForWatch,
            localConnectionConfig: settingsLocalConnectionConfiguration,
            remoteConnectionConfig: settingsRemoteConnectionConfiguration,
            homeName: settingsHomeName,
            sseCommandItem: settingsSSECommandItem
        )
    }

    var body: some View {
        Form {
            ConnectionSettingsView(
                settingsDemomode: $settingsDemomode,
                localConnectionConfiguration: $settingsLocalConnectionConfiguration,
                remoteConnectionConfiguration: $settingsRemoteConnectionConfiguration
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
                sitemaps: $sitemaps
            )

            DebugSettingsView(
                settingsSendCrashReports: $settingsSendCrashReports
            )

            AboutSettingsView()
        }
        .formStyle(.grouped)
        .navigationBarBackButtonHidden(isDirty)
        .navigationTitle("\(settingsHomeName) Settings")
        .toolbar {
            if isDirty {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveSettings()
                        NotificationCenter.default.post(name: NSNotification.Name("org.openhab.preferences.saved"), object: nil)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        restoreFromSnapshot()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .task {
            if !viewAppearedOnce {
                viewAppearedOnce = true
                loadSettings()
                initialSnapshot = currentSnapshot
                let activeConfiguration = settingsLocalConnectionConfiguration
                await updateSitemaps(activeConfiguration: activeConfiguration)
            }
        }
        .onChange(of: currentSnapshot) { _, newSnapshot in
            isDirty = newSnapshot != initialSnapshot
        }
    }

    private func restoreFromSnapshot() {
        guard let snapshot = initialSnapshot else { return }
        settingsDemomode = snapshot.demomode
        settingsIdleOff = snapshot.idleOff
        settingsRealTimeSliders = snapshot.realTimeSliders
        settingsShowSearchField = snapshot.showSearchField
        settingsSendCrashReports = snapshot.sendCrashReports
        settingsIconType = snapshot.iconType
        settingsSortSitemapsBy = snapshot.sortSitemapsBy
        settingsDefaultMainUIPath = snapshot.defaultMainUIPath
        settingsAlwaysAllowWebRTC = snapshot.alwaysAllowWebRTC
        settingsSitemapForWatch = snapshot.sitemapForWatch
        settingsLocalConnectionConfiguration = snapshot.localConnectionConfig
        settingsRemoteConnectionConfiguration = snapshot.remoteConnectionConfig
        settingsHomeName = snapshot.homeName
        settingsSSECommandItem = snapshot.sseCommandItem
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
        settingsSendCrashReports = Preferences.shared.sendCrashReports
        settingsIconType = IconType(rawValue: Preferences.shared.currentHomePreferences.iconType) ?? .svg
        settingsSortSitemapsBy = SortSitemapsOrder(rawValue: Preferences.shared.currentHomePreferences.sortSitemapsBy) ?? .label
        settingsDefaultMainUIPath = Preferences.shared.currentHomePreferences.defaultMainUIPath
        settingsAlwaysAllowWebRTC = Preferences.shared.currentHomePreferences.alwaysAllowWebRTC
        settingsSitemapForWatch = Preferences.shared.currentHomePreferences.sitemapForWatch
        settingsLocalConnectionConfiguration = Preferences.shared.currentHomePreferences.localConnectionConfig
        settingsRemoteConnectionConfiguration = Preferences.shared.currentHomePreferences.remoteConnectionConfig
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
            homePreferences.localConnectionConfig = settingsLocalConnectionConfiguration
            homePreferences.remoteConnectionConfig = settingsRemoteConnectionConfiguration
            homePreferences.sseCommandItem = settingsSSECommandItem
        }
        Preferences.shared.idleOff = settingsIdleOff
        Preferences.shared.sendCrashReports = settingsSendCrashReports

        Preferences.shared.modifyApplicationPreferences { @MainActor applicationPreferences in
            applicationPreferences.showSearchField = settingsShowSearchField
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
