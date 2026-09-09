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

import Combine
import CommonUI
import OpenHABCore
import os.log
import SafariServices
import SwiftUI

struct DebugSettingsView: View {
    @Binding var settingsSendCrashReports: Bool
    @Binding var settingsSitemapDiagnosticsLogging: Bool

    @State private var hasBeenLoaded = false
    @State var showCrashReportingAlert = false

    var body: some View {
        Toggle("Crash Reporting", isOn: $settingsSendCrashReports)
            .task { @MainActor in
                updateSettingsSendCrashReports(await Preferences.shared.sendCrashReports)
            }
            .onChange(of: settingsSendCrashReports) { _, newValue in
                #if !DEBUG
                Logger.settingsView.debug("Detected change on settingsSendCrashReports")
                #endif
                if newValue, hasBeenLoaded {
                    showCrashReportingAlert = true
                }
            }
            .confirmationDialog(
                "crash_reporting",
                isPresented: $showCrashReportingAlert
            ) {
                Button(role: .destructive) {
                    settingsSendCrashReports = true
                } label: {
                    Text(LocalizedStringKey("activate"))
                }
                Button(LocalizedStringKey("privacy_policy")) {
                    presentPrivacyPolicy()
                    settingsSendCrashReports = false
                }
                Button(role: .cancel) {
                    settingsSendCrashReports = false
                } label: {
                    Text(LocalizedStringKey("cancel"))
                }
            } message: {
                Text(LocalizedStringKey("crash_reporting_info"))
            }
        Section(header: Text(LocalizedStringKey("debug"))) {
            Toggle("Sitemap Diagnostics Logging", isOn: $settingsSitemapDiagnosticsLogging)
                .onChange(of: settingsSitemapDiagnosticsLogging) { _, newValue in
                    Task {
                        await Preferences.shared.modifyApplicationPreferences { prefs in
                            prefs.sitemapDiagnosticsLogging = newValue
                        }
                    }
                }
            NavigationLink {
                LogsViewer()
            } label: {
                Text("Logs")
            }
        }
    }

    func presentPrivacyPolicy() {
        let vc = SFSafariViewController(url: .privacyPolicy)
        UIApplication.shared.firstKeyWindow?.rootViewController?.present(vc, animated: true)
    }

    private func updateSettingsSendCrashReports(_ send: Bool) {
        settingsSendCrashReports = send
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var ignoreSSL = true
        @State private var idleOff = false
        @State private var sendCrashReports = false
        @State private var sitemapDiagnosticsLogging = false

        var body: some View {
            Form {
                DebugSettingsView(
                    settingsSendCrashReports: $sendCrashReports,
                    settingsSitemapDiagnosticsLogging: $sitemapDiagnosticsLogging
                )
            }
        }
    }

    return PreviewWrapper()
}
