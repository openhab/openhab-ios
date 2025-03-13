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

    @State private var sitemaps: [OpenHABSitemap] = []

    @Environment(\.dismiss) private var dismiss

    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

    private let logger = Logger(subsystem: "org.openhab.app", category: "SettingsView")

    var body: some View {
        Form {
            ConnectionSettingsView(
                settingsDemomode: $settingsDemomode,
                settingsLocalUrl: $settingsLocalUrl,
                settingsRemoteUrl: $settingsRemoteUrl,
                settingsUsername: $settingsUsername,
                settingsPassword: $settingsPassword,
                settingsAlwaysSendCreds: $settingsAlwaysSendCreds
            )

            ApplicationSettingsView(
                settingsIgnoreSSL: $settingsIgnoreSSL,
                settingsIdleOff: $settingsIdleOff,
                settingsSendCrashReports: $settingsSendCrashReports
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

            DebugSettingsView()

            AboutSettingsView()
        }
        .formStyle(.grouped)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitle("Settings")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Save") {
                    saveSettings()
                    appData?.sitemapViewController?.pageUrl = ""
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
        .onAppear {
            loadSettings()
            logger.debug("Loading Settings")
        }
    }

    func loadSettings() {
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
                page: nil // Replace with actual OpenHABPage if needed
            ),
            OpenHABSitemap(
                name: "office",
                icon: "",
                label: "Office",
                link: "http://192.168.1.100/rest/sitemaps/office",
                page: nil // Replace with actual OpenHABPage if needed
            )
        ]

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
                    settingsSitemapForWatch: settingsSitemapForWatch
                )
            }
        }
    }
    return PreviewWrapper()
}
