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

import OpenHABCore
import os
import SafariServices
import SwiftUI

// struct ApplicationSettingsView: View {
//    @Binding var settingsIgnoreSSL: Bool
//    @Binding var settingsIdleOff: Bool
//    @Binding var settingsSendCrashReports: Bool
//
//    @State var showCrashReportingAlert = false
//    @State private var hasBeenLoaded = false
//
//    private let logger = Logger(subsystem: "org.openhab.app", category: "ApplicationSettingsView")
//
//    var body: some View {
//        Section(header: Text(LocalizedStringKey("application_settings"))) {
//            Toggle(isOn: $settingsIgnoreSSL) {
//                Text("Ignore SSL certificates")
//            }
//
//            Toggle(isOn: $settingsIdleOff) {
//                Text("Disable Idle Timeout")
//            }
//
//            Toggle(isOn: $settingsSendCrashReports) {
//                Text("Crash Reporting")
//            }
//
//            .onAppear {
//                // Setting .onAppear of view required here because onAppear of entire view is run after .onChange is active
//                // when migrating to iOS17 this
//                settingsSendCrashReports = Preferences.sendCrashReports
//                //                    loadSitemaps()
//                hasBeenLoaded = true
//            }
//            .onChange(of: settingsSendCrashReports) { newValue in
//                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == nil {
//                       logger.debug("Detected change on settingsSendCrashReports")
//                }
//                if newValue, hasBeenLoaded {
//                    showCrashReportingAlert = true
//                }
//            }
//            .confirmationDialog(
//                "crash_reporting",
//                isPresented: $showCrashReportingAlert
//            ) {
//                Button(role: .destructive) {
//                    settingsSendCrashReports = true
//                } label: {
//                    Text(LocalizedStringKey("activate"))
//                }
//                Button(LocalizedStringKey("privacy_policy")) {
//                    presentPrivacyPolicy()
//                    settingsSendCrashReports = false
//                }
//                Button(role: .cancel) {
//                    settingsSendCrashReports = false
//                } label: {
//                    Text(LocalizedStringKey("cancel"))
//                }
//            } message: {
//                Text(LocalizedStringKey("crash_reporting_info"))
//            }
//
//            NavigationLink {
//                ClientCertificatesView()
//            } label: {
//                Text("Client Certificates")
//            }
//        }
//    }
//
//    func presentPrivacyPolicy() {
//        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == nil {
//            let vc = SFSafariViewController(url: .privacyPolicy)
//            UIApplication.shared.firstKeyWindow?.rootViewController?.present(vc, animated: true)
//        }
//    }
// }

struct ApplicationSettingsView: View {
    @Binding var settingsIgnoreSSL: Bool
    @Binding var settingsIdleOff: Bool
    @Binding var settingsSendCrashReports: Bool

    @State var showCrashReportingAlert = false
    @State private var hasBeenLoaded = false

    private let logger = Logger(subsystem: "org.openhab.app", category: "ApplicationSettingsView")

    var body: some View {
        Section(header: Text(LocalizedStringKey("application_settings"))) {
            Toggle("Ignore SSL certificates", isOn: $settingsIgnoreSSL)
            Toggle("Disable Idle Timeout", isOn: $settingsIdleOff)
            Toggle("Crash Reporting", isOn: $settingsSendCrashReports)
                .task {
                    settingsSendCrashReports = Preferences.sendCrashReports
                }
                .onChange(of: settingsSendCrashReports) { newValue in
                    #if !DEBUG
                    logger.debug("Detected change on settingsSendCrashReports")
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

            NavigationLink("Client Certificates") {
                ClientCertificatesView()
            }
        }
    }

    func presentPrivacyPolicy() {
        let vc = SFSafariViewController(url: .privacyPolicy)
        UIApplication.shared.firstKeyWindow?.rootViewController?.present(vc, animated: true)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var ignoreSSL = true
        @State private var idleOff = false
        @State private var sendCrashReports = false

        var body: some View {
            Form {
                ApplicationSettingsView(
                    settingsIgnoreSSL: $ignoreSSL,
                    settingsIdleOff: $idleOff,
                    settingsSendCrashReports: $sendCrashReports
                )
            }
        }
    }

    return PreviewWrapper()
}
