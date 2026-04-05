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
import SFSafeSymbols
import SwiftUI
import WebKit

struct MainUISettingsView: View {
    @Binding var settingsAlwaysAllowWebRTC: Bool
    @Binding var settingsDefaultMainUIPath: String

    @State var showUselastPathAlert = false
    @State var showingCacheAlert = false

    var body: some View {
        Section(header: Text(LocalizedStringKey("mainui_settings"))) {
            Toggle(isOn: $settingsAlwaysAllowWebRTC) {
                Text("Always allow WebRTC")
            }

            LabeledContent {
                HStack {
                    TextField(
                        "/overview/",
                        text: $settingsDefaultMainUIPath
                    )
                    .multilineTextAlignment(.trailing)
                    Button {
                        showUselastPathAlert = true
                    } label: {
                        Image(systemSymbol: .clear)
                    }
                    .confirmationDialog(
                        "uselastpath_settings",
                        isPresented: $showUselastPathAlert
                    ) {
                        Button("OK") {
                            settingsDefaultMainUIPath = Preferences.shared.currentWebViewPath
                        }
                        Button(role: .cancel) {} label: {
                            Text(LocalizedStringKey("cancel"))
                        }
                        Button("cancel", role: .cancel) {}
                    } message: {
                        Text(LocalizedStringKey("uselastpath_settings"))
                    }
                }

            } label: {
                Text("Default Path")
            }

            Button {
                let websiteDataTypes: Set<String> = [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]
                let date = Date(timeIntervalSince1970: 0)
                WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes, modifiedSince: date) {}
                showingCacheAlert = true
            } label: {
                NavigationLink("Clear Web Cache", destination: EmptyView())
            }
            .foregroundStyle(Color(uiColor: .label))
            .alert("cache_cleared", isPresented: $showingCacheAlert) {
                Button("OK", role: .cancel) {}
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var alwaysAllowWebRTC = true
        @State var defaultMainUIPath = "/overview/"
        @State var showLastPathAlert = false
        @State var showUselastPathAlert = false

        var body: some View {
            NavigationStack {
                Form {
                    MainUISettingsView(
                        settingsAlwaysAllowWebRTC: $alwaysAllowWebRTC,
                        settingsDefaultMainUIPath: $defaultMainUIPath
                    )
                }
            }
        }
    }
    return PreviewWrapper()
}
