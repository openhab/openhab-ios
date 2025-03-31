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
    @State var settingsLocalUrl = ""
    @State var settingsRemoteUrl = ""
    @State var settingsUsername = ""
    @State var settingsPassword = ""
    @State var settingsAlwaysSendCreds = true
    @State var settingsIdleOff = true
    @State var settingsIgnoreSSL = true
    @State var settingsRealTimeSliders = true
    @State var settingsSendCrashReports = false
    @State var settingsIconType: IconType = .png
    @State var settingsSortSitemapsBy: SortSitemapsOrder = .label
    @State var settingsDefaultMainUIPath = ""
    @State var settingsAlwaysAllowWebRTC = true
    @State var settingsSitemapForWatch = ""

    @State var sitemaps: [OpenHABSitemap] = []
    @State var settingsLocalConnectionConfiguration = ConnectionConfiguration(url: "", username: "", password: "")
    @State var settingsRemoteConnectionConfiguration = ConnectionConfiguration(url: "", username: "", password: "")

    @Environment(\.dismiss) private var dismiss

    private let logger = Logger(subsystem: "org.openhab.app", category: "SettingsView")

    var body: some View {
        Form {
            ConnectionSettingsView(
                settingsDemomode: $settingsDemomode,
                localConnectionConfiguration: $settingsLocalConnectionConfiguration,
                remoteConnectionConfiguration: $settingsRemoteConnectionConfiguration
            )

            ApplicationSettingsView(
                settingsIdleOff: $settingsIdleOff
            )

            MainUISettingsView(
                settingsAlwaysAllowWebRTC: $settingsAlwaysAllowWebRTC,
                settingsDefaultMainUIPath: $settingsDefaultMainUIPath
            )

            SitemapSettingsView(
                settingsRealTimeSliders: $settingsRealTimeSliders,
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
        .navigationBarTitle("Settings")
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
            loadSettings()
            let activeConfiguration = settingsLocalConnectionConfiguration
            await updateSitemaps(activeConfiguration: activeConfiguration)
        }
    }

    private func updateSitemaps(activeConfiguration: ConnectionConfiguration) async {
        let openAPIService = OpenAPIService(connectionConfiguration: activeConfiguration)

        do {
            sitemaps = try await openAPIService.openHABSitemaps()
            if sitemaps.last?.name == "_default", sitemaps.count > 1 {
                sitemaps = Array(sitemaps.dropLast())
            }

            // Sort the sitemaps according to Settings selection.
            switch SortSitemapsOrder(rawValue: Preferences.sortSitemapsby) ?? .label {
            case .label: sitemaps.sort { $0.label < $1.label }
            case .name: sitemaps.sort { $0.name < $1.name }
            }
        } catch {
            os_log("%{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
            sitemaps = []
        }
    }

    private func loadSettings() {
        #if !DEBUG
        logger.debug("Loading Settings")
        #endif
        settingsLocalUrl = Preferences.localUrl
        settingsRemoteUrl = Preferences.remoteUrl
        settingsUsername = Preferences.username
        settingsPassword = Preferences.password
        settingsAlwaysSendCreds = Preferences.alwaysSendCreds
        settingsIgnoreSSL = Preferences.ignoreSSL
        settingsDemomode = Preferences.demomode
        settingsIdleOff = Preferences.idleOff
        settingsRealTimeSliders = Preferences.realTimeSliders
        settingsSendCrashReports = Preferences.sendCrashReports
        settingsIconType = IconType(rawValue: Preferences.iconType) ?? .png
        settingsSortSitemapsBy = SortSitemapsOrder(rawValue: Preferences.sortSitemapsby) ?? .label
        settingsDefaultMainUIPath = Preferences.defaultMainUIPath
        settingsAlwaysAllowWebRTC = Preferences.alwaysAllowWebRTC
        settingsSitemapForWatch = Preferences.sitemapForWatch
        settingsLocalConnectionConfiguration = Preferences.localConnectionConfig
        settingsRemoteConnectionConfiguration = Preferences.remoteConnectionConfig
    }

    func saveSettings() {
        Preferences.localUrl = settingsLocalUrl
        Preferences.remoteUrl = settingsRemoteUrl
        Preferences.username = settingsUsername
        Preferences.password = settingsPassword
        Preferences.alwaysSendCreds = settingsAlwaysSendCreds
        Preferences.ignoreSSL = settingsIgnoreSSL
        Preferences.demomode = settingsDemomode
        Preferences.idleOff = settingsIdleOff
        Preferences.realTimeSliders = settingsRealTimeSliders
        Preferences.iconType = settingsIconType.rawValue
        Preferences.sendCrashReports = settingsSendCrashReports
        Preferences.sortSitemapsby = settingsSortSitemapsBy.rawValue
        Preferences.defaultMainUIPath = settingsDefaultMainUIPath
        Preferences.alwaysAllowWebRTC = settingsAlwaysAllowWebRTC
        Preferences.sitemapForWatch = settingsSitemapForWatch
        Preferences.localConnectionConfig = settingsLocalConnectionConfiguration
        Preferences.remoteConnectionConfig = settingsRemoteConnectionConfiguration
        WatchMessageService.singleton.syncPreferencesToWatch()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(settingsSendCrashReports)
        logger.debug("setCrashlyticsCollectionEnabled to \(settingsSendCrashReports)")
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
        @State var settingsLocalUrl = "http://192.168.1.100"
        @State var settingsRemoteUrl = "https://myopenhab.org"
        @State var settingsUsername = "user"
        @State var settingsPassword = "password123"
        @State var settingsAlwaysSendCreds = true
        @State var settingsIdleOff = true
        @State var settingsIgnoreSSL = true
        @State var settingsRealTimeSliders = true
        @State var settingsSendCrashReports = false
        @State var settingsIconType: IconType = .png
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
                    settingsLocalUrl: settingsLocalUrl,
                    settingsRemoteUrl: settingsRemoteUrl,
                    settingsUsername: settingsUsername,
                    settingsPassword: settingsPassword,
                    settingsAlwaysSendCreds: settingsAlwaysSendCreds,
                    settingsIdleOff: settingsIdleOff,
                    settingsIgnoreSSL: settingsIgnoreSSL,
                    settingsRealTimeSliders: settingsRealTimeSliders,
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
