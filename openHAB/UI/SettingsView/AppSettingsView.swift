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
        var showSearchField: Bool
    }

    private var currentSnapshot: AppSettingsSnapshot {
        AppSettingsSnapshot(
            idleOff: settingsIdleOff,
            sendCrashReports: settingsSendCrashReports,
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
                Toggle("Hide Status Bar", isOn: Binding(
                    get: { Preferences.shared.hideStatusBar },
                    set: { Preferences.shared.hideStatusBar = $0 }
                ))
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
            // Sheet was swiped away with unsaved changes — auto-save
            saveSettings()
            NotificationCenter.default.post(name: NSNotification.Name("org.openhab.preferences.saved"), object: nil)
        }
        .onChange(of: currentSnapshot) { newSnapshot in
            isDirty = newSnapshot != initialSnapshot
        }
        .task {
            guard !viewAppearedOnce else { return }
            viewAppearedOnce = true
            loadSettings()
            initialSnapshot = currentSnapshot
        }
    }

    private func loadSettings() {
        settingsIdleOff = Preferences.shared.idleOff
        settingsSendCrashReports = Preferences.shared.sendCrashReports
        settingsShowSearchField = Preferences.shared.applicationPreferences.showSearchField
        settingsSitemapDiagnosticsLogging = Preferences.shared.applicationPreferences.sitemapDiagnosticsLogging
    }

    private func saveSettings() {
        Preferences.shared.idleOff = settingsIdleOff
        Preferences.shared.sendCrashReports = settingsSendCrashReports
        Preferences.shared.modifyApplicationPreferences { @MainActor prefs in
            prefs.showSearchField = settingsShowSearchField
            prefs.sitemapDiagnosticsLogging = settingsSitemapDiagnosticsLogging
        }
    }
}

#Preview {
    NavigationStack {
        AppSettingsView()
    }
}
