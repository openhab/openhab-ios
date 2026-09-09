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

import OpenHABCore
import os
import SwiftUI

struct AppSettingsView: View, SettingsSheetView {
    @State var current = AppSettingsSnapshot()
    @State var initial = AppSettingsSnapshot()
    @State private var settingsSitemapDiagnosticsLogging = false
    @State private var viewAppearedOnce = false

    @Environment(\.dismiss) private var dismiss

    struct AppSettingsSnapshot: Equatable {
        var idleOff: Bool = true
        var sendCrashReports: Bool = false
        var hideStatusBar: Bool = false
        var showSearchField: Bool = true
    }

    var body: some View {
        Form {
            Section {
                Toggle("Disable Idle Timeout", isOn: $current.idleOff)
                NavigationLink("Screen Saver Settings") {
                    ScreenSaverSettingsView()
                }
            }

            Section(header: Text("User Interface")) {
                Toggle("Hide Status Bar", isOn: $current.hideStatusBar)
                Toggle("Show Search Field in Sitemaps", isOn: $current.showSearchField)
            }

            Section(header: Text("Security")) {
                NavigationLink("Client Certificates") {
                    ClientCertificatesView()
                }
                NavigationLink("Accepted Server Certificates") {
                    ServerCertificatesView()
                }
            }

            DebugSettingsView(
                settingsSendCrashReports: $current.sendCrashReports,
                settingsSitemapDiagnosticsLogging: $settingsSitemapDiagnosticsLogging
            )

            AboutSettingsView()
        }
        .formStyle(.grouped)
        .navigationTitle("App Settings")
        .settingsSheet(from: self)
        .task {
            guard !viewAppearedOnce else { return }
            viewAppearedOnce = true
            current = await AppSettingsSnapshot(from: .shared)
            settingsSitemapDiagnosticsLogging = (await Preferences.shared.applicationPreferences).sitemapDiagnosticsLogging
            initial = current
        }
    }

    func onSave() {
        Task { @MainActor in
            await saveSettings()
            NotificationCenter.default.post(name: NSNotification.Name("org.openhab.preferences.saved"), object: nil)
            dismiss()
        }
    }

    func onRevert() { current = initial }

    func onCancel() {
        dismiss()
    }

    private func saveSettings() async {
        await Preferences.shared.setIdleOff(current.idleOff)
        await Preferences.shared.setSendCrashReports(current.sendCrashReports)
        await Preferences.shared.setHideStatusBar(current.hideStatusBar)
        let showSearchField = current.showSearchField
        let sitemapDiagnosticsLogging = settingsSitemapDiagnosticsLogging
        await Preferences.shared.modifyApplicationPreferences { prefs in
            prefs.showSearchField = showSearchField
            prefs.sitemapDiagnosticsLogging = sitemapDiagnosticsLogging
        }
    }
}

extension AppSettingsView.AppSettingsSnapshot {
    /// Loads a snapshot from a `Preferences` instance.
    init(from preferences: Preferences) async {
        idleOff = await preferences.idleOff
        sendCrashReports = await preferences.sendCrashReports
        hideStatusBar = await preferences.hideStatusBar
        showSearchField = (await preferences.applicationPreferences).showSearchField
    }
}

#Preview {
    NavigationStack {
        AppSettingsView()
    }
}
