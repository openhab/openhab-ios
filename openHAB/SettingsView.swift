// Copyright (c) 2010-2024 Contributors to the openHAB project
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
import Kingfisher
import OpenHABCore
import os
import SafariServices
import SFSafeSymbols
import SwiftUI
import WebKit

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

    @State private var showingCacheAlert = false
    @State private var showCrashReportingAlert = false
    @State private var showUselastPathAlert = false

    @State private var hasBeenLoaded = false

    @Environment(\.dismiss) private var dismiss

    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

    var appVersion: String {
        let appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "\(appVersionString ?? "") (\(appBuildString ?? ""))"
    }

    private let logger = Logger(subsystem: "org.openhab.app", category: "SettingsView")

    var body: some View {
        Form {
            Section(header: Text(LocalizedStringKey("openhab_connection"))) {
                Toggle(isOn: $settingsDemomode) {
                    Text("Demo Mode")
                }

                if !settingsDemomode {
                    LabeledContent {
                        Spacer()
                        TextField(
                            "Local URL",
                            text: $settingsLocalUrl
                        )
                        .fixedSize()
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.system(.caption))
                    } label: {
                        Text("Local URL")
                        if settingsLocalUrl.isEmpty {
                            Text("Enter URL of local server")
                        }
                    }

                    LabeledContent {
                        Spacer()
                        TextField(
                            "Remote URL",
                            text: $settingsRemoteUrl
                        )
                        .fixedSize()
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.system(.caption))
                    } label: {
                        Text("Remote URL")
                        if settingsRemoteUrl.isEmpty {
                            Text("Enter URL of remote server")
                        }
                    }

                    LabeledContent {
                        TextField(
                            "Foo",
                            text: $settingsUsername
                        )
                        .fixedSize()
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.system(.caption))
                    } label: {
                        Text("Username")
                        if settingsUsername.isEmpty {
                            Text("Enter username on server, if required")
                        }
                    }

                    LabeledContent {
                        SecureField(
                            "1234",
                            text: $settingsPassword
                        )
                        .fixedSize()
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.system(.caption))

                    } label: {
                        Text("Password")
                        if settingsPassword.isEmpty {
                            Text("Enter password on server")
                        }
                    }

                    Toggle(isOn: $settingsAlwaysSendCreds) {
                        Text("Always send credentials")
                    }
                }
            }

            Section(header: Text(LocalizedStringKey("application_settings"))) {
                Toggle(isOn: $settingsIgnoreSSL) {
                    Text("Ignore SSL certificates")
                }

                Toggle(isOn: $settingsIdleOff) {
                    Text("Disable Idle Timeout")
                }

                Toggle(isOn: $settingsSendCrashReports) {
                    Text("Crash Reporting")
                }

                .onAppear {
                    // Setting .onAppear of view required here because onAppear of entire view is run after onChange is active
                    // when migrating to iOS17 this
                    settingsSendCrashReports = Preferences.sendCrashReports
                    hasBeenLoaded = true
                }
                .onChange(of: settingsSendCrashReports) { newValue in
                    logger.debug("Detected change on settingsSendCrashReports")
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

                NavigationLink {
                    ClientCertificatesView()
                } label: {
                    Text("Client Certificates")
                }
            }

            Section(header: Text(LocalizedStringKey("mainui_settings"))) {
                Toggle(isOn: $settingsAlwaysAllowWebRTC) {
                    Text("Always allow WebRTC")
                }

                LabeledContent {
                    TextField(
                        "/overview/",
                        text: $settingsDefaultMainUIPath
                    )
                    .fixedSize()
                    Button {
                        showUselastPathAlert = true
                    } label: {
                        Image(systemSymbol: .plusCircle)
                    }
                    .confirmationDialog(
                        "uselastpath_settings",
                        isPresented: $showUselastPathAlert
                    ) {
                        Button("Ok") {
                            if let path = appData?.currentWebViewPath {
                                settingsDefaultMainUIPath = path
                            }
                        }
                        Button(role: .cancel) {} label: {
                            Text(LocalizedStringKey("cancel"))
                        }
                        Button("cancel", role: .cancel) {}
                    } message: {
                        Text(LocalizedStringKey("uselastpath_settings"))
                    }

                } label: {
                    Text("Default Path")
                }

                Button {
                    let websiteDataTypes = NSSet(array: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])
                    let date = Date(timeIntervalSince1970: 0)
                    WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes as! Set<String>, modifiedSince: date) {}
                    showingCacheAlert = true
                } label: {
                    NavigationLink("Clear Web Cache", destination: EmptyView())
                }
                .foregroundColor(Color(uiColor: .label))
                .alert("cache_cleared", isPresented: $showingCacheAlert) {
                    Button("OK", role: .cancel) {}
                }
            }

            Section(header: Text(LocalizedStringKey("sitemap_settings"))) {
                Toggle(isOn: $settingsRealTimeSliders) {
                    Text("Real-time Sliders")
                }

                Button {
                    clearWebsiteCache()
                    showingCacheAlert = true
                } label: {
                    NavigationLink("Clear Image Cache", destination: EmptyView())
                }
                .foregroundColor(Color(uiColor: .label))
                .alert("cache_cleared", isPresented: $showingCacheAlert) {
                    Button("OK", role: .cancel) {}
                }

                Picker(selection: $settingsIconType) {
                    ForEach(IconType.allCases, id: \.self) { icontype in
                        Text("\(icontype)").tag(icontype)
                    }
                } label: {
                    Text("Icon Type")
                }

                Picker(selection: $settingsSortSitemapsBy) {
                    ForEach(SortSitemapsOrder.allCases, id: \.self) { sortsitemaporder in
                        Text("\(sortsitemaporder)").tag(sortsitemaporder)
                    }
                } label: {
                    Text("Sort sitemaps by")
                }
            }

            Section(header: Text(LocalizedStringKey("about_settings"))) {
                LabeledContent("App Version", value: appVersion)

                NavigationLink {
                    RTFTextView(rtfFileName: "legal")
                        .navigationTitle("Legal")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Text("Legal")
                }

                Button {
                    presentPrivacyPolicy()
                } label: {
                    Text("privacy_policy")
                }
            }
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

    func clearWebsiteCache() {
        logger.debug("Clearing image cache")
        KingfisherManager.shared.cache.clearMemoryCache()
        KingfisherManager.shared.cache.clearDiskCache()
        KingfisherManager.shared.cache.cleanExpiredDiskCache()
    }

    func presentPrivacyPolicy() {
        let vc = SFSafariViewController(url: .privacyPolicy)
        UIApplication.shared.firstKeyWindow?.rootViewController?.present(vc, animated: true)
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
    SettingsView()
}
