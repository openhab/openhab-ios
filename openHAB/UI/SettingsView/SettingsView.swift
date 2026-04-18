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
    /// Called after the sheet is dismissed via swipe with unsaved changes.
    /// The passed closure performs the save when invoked by the parent.
    var onDismissedDirty: ((SettingsSnapshot, @escaping () -> Void) -> Void)?
    var initialValues: SettingsSnapshot?

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

    @State private var sitemaps: [OpenHABSitemap] = []
    @State private var settingsLocalConnectionConfiguration = ConnectionConfiguration(url: "", username: "", password: "")
    @State private var settingsRemoteConnectionConfiguration = ConnectionConfiguration(url: "", username: "", password: "")
    @State private var settingsHomeName = ""
    @State private var viewAppearedOnce = false
    @State private var settingsSSECommandItem = ""

    @State private var initialSnapshot: SettingsSnapshot?
    @State private var isDirty = false
    @State private var savedExplicitly = false

    @Environment(\.dismiss) private var dismiss

    struct SettingsSnapshot: Equatable {
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
        var sseCommandItem: String
    }

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
                settingsSendCrashReports: $settingsSendCrashReports,
                settingsSitemapDiagnosticsLogging: $settingsSitemapDiagnosticsLogging
            )

            AboutSettingsView()
        }
        .formStyle(.grouped)
        .navigationTitle("\(settingsHomeName) Settings")
        .toolbar {
            if isDirty {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        savedExplicitly = true
                        saveSettings()
                        NotificationCenter.default.post(name: NSNotification.Name("org.openhab.preferences.saved"), object: nil)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    savedExplicitly = true // treat explicit X as intentional discard — no dialog
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
        .onDisappear {
            guard isDirty, !savedExplicitly else { return }
            // Sheet was swiped away with unsaved changes — capture values and notify parent
            let dm = settingsDemomode, io = settingsIdleOff, rts = settingsRealTimeSliders
            let ssf = settingsShowSearchField, scr = settingsSendCrashReports
            let it = settingsIconType, ssb = settingsSortSitemapsBy
            let dmu = settingsDefaultMainUIPath, aawrtc = settingsAlwaysAllowWebRTC
            let sfw = settingsSitemapForWatch
            let sfwLabel = sitemaps.first { $0.name == sfw }?.label ?? "unknown"
            let lcc = settingsLocalConnectionConfiguration
            let rcc = settingsRemoteConnectionConfiguration
            let sseCI = settingsSSECommandItem
            let snapshot = currentSnapshot
            onDismissedDirty?(snapshot) {
                Preferences.shared.modifyActiveHome { @MainActor prefs in
                    prefs.demomode = dm
                    prefs.realTimeSliders = rts
                    prefs.iconType = it.rawValue
                    prefs.sortSitemapsBy = ssb.rawValue
                    prefs.defaultMainUIPath = dmu
                    prefs.alwaysAllowWebRTC = aawrtc
                    prefs.sitemapForWatch = sfw
                    prefs.sitemapForWatchLabel = sfwLabel
                    prefs.localConnectionConfig = lcc
                    prefs.remoteConnectionConfig = rcc
                    prefs.sseCommandItem = sseCI
                }
                Preferences.shared.idleOff = io
                Preferences.shared.sendCrashReports = scr
                Preferences.shared.modifyApplicationPreferences { @MainActor prefs in
                    prefs.showSearchField = ssf
                }
                NotificationCenter.default.post(name: NSNotification.Name("org.openhab.preferences.saved"), object: nil)
            }
        }
        .onChange(of: currentSnapshot) { newSnapshot in
            isDirty = newSnapshot != initialSnapshot
        }
        .task {
            if !viewAppearedOnce {
                viewAppearedOnce = true
                loadSettings()
                initialSnapshot = currentSnapshot
                if let initialValues {
                    applySnapshot(initialValues)
                }
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
        settingsSitemapDiagnosticsLogging = Preferences.shared.applicationPreferences.sitemapDiagnosticsLogging
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

    private func applySnapshot(_ snapshot: SettingsSnapshot) {
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
        settingsSSECommandItem = snapshot.sseCommandItem
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
