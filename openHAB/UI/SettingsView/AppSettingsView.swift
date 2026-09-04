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

struct AppSettingsView: View {
    @State private var settingsIdleOff = true
    @State private var settingsSendCrashReports = false
    @State private var settingsHideStatusBar = false
    @State private var settingsShowSearchField = true
    @State private var settingsSitemapDiagnosticsLogging = false

    @State private var viewAppearedOnce = false
    @State private var initialSnapshot: AppSettingsSnapshot?
    @State private var isDirty = false
    @State private var savedExplicitly = false

    @Environment(\.dismiss) private var dismiss

    struct AppSettingsSnapshot: Equatable {
        var idleOff: Bool
        var sendCrashReports: Bool
        var hideStatusBar: Bool
        var showSearchField: Bool
    }

    private var currentSnapshot: AppSettingsSnapshot {
        AppSettingsSnapshot(
            idleOff: settingsIdleOff,
            sendCrashReports: settingsSendCrashReports,
            hideStatusBar: settingsHideStatusBar,
            showSearchField: settingsShowSearchField
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle("Disable Idle Timeout", isOn: $settingsIdleOff)
                NavigationLink("Screen Saver Settings") {
                    ScreenSaverSettingsView()
                }
            }

            Section(header: Text("User Interface")) {
                Toggle("Hide Status Bar", isOn: $settingsHideStatusBar)
                Toggle("Show Search Field in Sitemaps", isOn: $settingsShowSearchField)
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
                settingsSendCrashReports: $settingsSendCrashReports,
                settingsSitemapDiagnosticsLogging: $settingsSitemapDiagnosticsLogging
            )

            AboutSettingsView()
        }
        .formStyle(.grouped)
        .navigationTitle("App Settings")
        .toolbar {
            if isDirty {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        savedExplicitly = true
                        Task { @MainActor in
                            await saveSettings()
                            NotificationCenter.default.post(name: NSNotification.Name("org.openhab.preferences.saved"), object: nil)
                            dismiss()
                        }
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
            // Sheet was swiped away with unsaved changes — auto-save
            Task { @MainActor in
                await saveSettings()
                NotificationCenter.default.post(name: NSNotification.Name("org.openhab.preferences.saved"), object: nil)
            }
        }
        .onChange(of: currentSnapshot) { _, newSnapshot in
            isDirty = newSnapshot != initialSnapshot
        }
        .task {
            guard !viewAppearedOnce else { return }
            viewAppearedOnce = true
            await loadSettings()
            initialSnapshot = currentSnapshot
        }
    }

    private func loadSettings() async {
        settingsIdleOff = await Preferences.shared.idleOff
        settingsSendCrashReports = await Preferences.shared.sendCrashReports
        settingsHideStatusBar = await Preferences.shared.hideStatusBar
        let appPrefs = await Preferences.shared.applicationPreferences
        settingsShowSearchField = appPrefs.showSearchField
        settingsSitemapDiagnosticsLogging = appPrefs.sitemapDiagnosticsLogging
    }

    private func saveSettings() async {
        await Preferences.shared.setIdleOff(settingsIdleOff)
        await Preferences.shared.setSendCrashReports(settingsSendCrashReports)
        await Preferences.shared.setHideStatusBar(settingsHideStatusBar)
        let showSearchField = settingsShowSearchField
        let sitemapDiagnosticsLogging = settingsSitemapDiagnosticsLogging
        await Preferences.shared.modifyApplicationPreferences { prefs in
            prefs.showSearchField = showSearchField
            prefs.sitemapDiagnosticsLogging = sitemapDiagnosticsLogging
        }
    }
}

#Preview {
    NavigationStack {
        AppSettingsView()
    }
}
