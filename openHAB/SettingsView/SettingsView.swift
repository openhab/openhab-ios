// Copyright (c) 2010-2025 Contributors to the openHAB project
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
    @State var settingsDemomode = false
    @State var settingsIdleOff = true
    @State var settingsRealTimeSliders = true
    @State var settingsShowSearchField = true
    @State var settingsSendCrashReports = false
    @State var settingsIconType: IconType = .svg
    @State var settingsSortSitemapsBy: SortSitemapsOrder = .label
    @State var settingsDefaultMainUIPath = ""
    @State var settingsAlwaysAllowWebRTC = true
    @State var settingsSitemapForWatch = ""

    @State var sitemaps: [OpenHABSitemap] = []
    @State var settingsLocalConnectionConfiguration = ConnectionConfiguration(url: "", username: "", password: "")
    @State var settingsRemoteConnectionConfiguration = ConnectionConfiguration(url: "", username: "", password: "")
    @State var settingsHomeName = ""
    @State var viewAppearedOnce = false
    @State var settingsSSECommandItem = ""

    @Environment(\.dismiss) private var dismiss

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
        .navigationBarBackButtonHidden(true)
        .navigationBarTitle("\(settingsHomeName) Settings")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Save") {
                    saveSettings()
                    NotificationCenter.default.post(name: NSNotification.Name("org.openhab.preferences.saved"), object: nil)
                    dismiss()
                }
            }
            ToolbarItemGroup(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .task {
            if !viewAppearedOnce {
                viewAppearedOnce = true
                loadSettings()
                let activeConfiguration = settingsLocalConnectionConfiguration
                await updateSitemaps(activeConfiguration: activeConfiguration)
            }
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
    struct PreviewWrapper: View {
        @State var settingsDemomode = false
        @State var settingsIdleOff = true
        @State var settingsRealTimeSliders = true
        @State var settingsShowSearchField = true
        @State var settingsSendCrashReports = false
        @State var settingsIconType: IconType = .svg
        @State var settingsSortSitemapsBy: SortSitemapsOrder = .label
        @State var settingsDefaultMainUIPath = "/overview/"
        @State var settingsAlwaysAllowWebRTC = true
        @State var settingsSitemapForWatch = "home"
        @State var sitemaps: [OpenHABSitemap] = [
            OpenHABSitemap(
                name: "home",
                icon: "",
                label: "Home",
                link: "http://192.168.1.100/rest/sitemaps/home",
                page: nil
            ),
            OpenHABSitemap(
                name: "office",
                icon: "",
                label: "Office",
                link: "http://192.168.1.100/rest/sitemaps/office",
                page: nil
            )
        ]
        @State var localConnectionConfiguration = ConnectionConfiguration(
            url: "http://192.168.2.1",
            username: "user",
            password: "password123"
        )
        @State var remoteConnectionConfiguration = ConnectionConfiguration(
            url: "http://192.168.2.1",
            username: "user",
            password: "password123"
        )

        var body: some View {
            NavigationView {
                SettingsView(
                    settingsDemomode: settingsDemomode,
                    settingsIdleOff: settingsIdleOff,
                    settingsRealTimeSliders: settingsRealTimeSliders,
                    settingsShowSearchField: settingsShowSearchField,
                    settingsSendCrashReports: settingsSendCrashReports,
                    settingsIconType: settingsIconType,
                    settingsSortSitemapsBy: settingsSortSitemapsBy,
                    settingsDefaultMainUIPath: settingsDefaultMainUIPath,
                    settingsAlwaysAllowWebRTC: settingsAlwaysAllowWebRTC,
                    settingsSitemapForWatch: settingsSitemapForWatch,
                    sitemaps: sitemaps,
                    settingsLocalConnectionConfiguration: localConnectionConfiguration,
                    settingsRemoteConnectionConfiguration: remoteConnectionConfiguration
                )
            }
            .onAppear {
                // Mock behavior of updateSitemaps
                if settingsSitemapForWatch.isEmpty, let first = sitemaps.first {
                    settingsSitemapForWatch = first.name
                }
            }
        }
    }
    return PreviewWrapper()
}
