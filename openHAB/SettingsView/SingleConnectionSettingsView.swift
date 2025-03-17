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
import SFSafeSymbols
import SwiftUI

struct SingleConnectionSettingsView: View {
    var headerText: String
    @Binding var connectionConfig: ConnectionConfiguration

    var body: some View {
        Section(header: Text(headerText)) {
            LabeledContent {
                Spacer()
                TextField(
                    "URL",
                    text: $connectionConfig.url
                )
                .fixedSize()
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.system(.caption))
            } label: {
                Text("URL")
                if connectionConfig.url.isEmpty {
                    Text("Enter URL of remote server")
                }
            }

            LabeledContent {
                TextField(
                    "Foo",
                    text: $connectionConfig.username
                )
                .textContentType(.username) // Associates with AutoFill
                .fixedSize()
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.system(.caption))
            } label: {
                Text("Username")
                if connectionConfig.username.isEmpty {
                    Text("Enter username on server, if required")
                }
            }

            LabeledContent {
                AnimatedSecureTextField(text: $connectionConfig.password, titleKey: "password")
                    .fixedSize()
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true) //   or  .autocorrectionDisabled(true) ??
                    .font(.system(.caption))
                    .textContentType(.password) // Associates with AutoFill
            } label: {
                Text("Password")
                if connectionConfig.password.isEmpty {
                    Text("Enter password on server")
                }
            }

            Toggle(isOn: $connectionConfig.alwaysSendBasicAuth) {
                Text("Always send credentials")
            }

            Toggle("Ignore SSL certificates", isOn: $connectionConfig.ignoreSSL)
        }
    }
}

// **TODO Migrate to @Previewable on iOS 17
#Preview {
    struct PreviewWrapper: View {
        @State var connectionConfig = ConnectionConfiguration(
            url: "http://192.168.2.1",
            username: "user",
            password: "password123"
        )

        var body: some View {
            NavigationView {
                Form {
                    SingleConnectionSettingsView(headerText: "Connection Settings for local server", connectionConfig: $connectionConfig)
                }
            }
        }
    }
    return PreviewWrapper()
}
