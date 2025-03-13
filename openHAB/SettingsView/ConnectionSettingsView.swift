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

import SwiftUI

struct ConnectionSettingsView: View {
    @Binding var settingsDemomode: Bool
    @Binding var settingsLocalUrl: String
    @Binding var settingsRemoteUrl: String
    @Binding var settingsUsername: String
    @Binding var settingsPassword: String
    @Binding var settingsAlwaysSendCreds: Bool

    var body: some View {
        Section(header: Text("OpenHAB Connection")) {
            Toggle("Demo Mode", isOn: $settingsDemomode)

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
                    .textContentType(.username) // Associates with AutoFill
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
                    .disableAutocorrection(true) //   or  .autocorrectionDisabled(true) ??
                    .font(.system(.caption))
                    .textContentType(.password) // Associates with AutoFill
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
    }
}

// **TODO Migrate to @Previewable on iOS 17
#Preview {
    struct PreviewWrapper: View {
        @State var demoMode = false
        @State var localUrl = "http://192.168.1.100"
        @State var remoteUrl = "https://myopenhab.org"
        @State var username = "user"
        @State var password = "password123"
        @State var alwaysSendCreds = true

        var body: some View {
            NavigationView {
                Form {
                    ConnectionSettingsView(
                        settingsDemomode: $demoMode,
                        settingsLocalUrl: $localUrl,
                        settingsRemoteUrl: $remoteUrl,
                        settingsUsername: $username,
                        settingsPassword: $password,
                        settingsAlwaysSendCreds: $alwaysSendCreds
                    )
                }
            }
        }
    }
    return PreviewWrapper()
}
