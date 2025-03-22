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

    @State private var isTestingConnection = false
    @State private var connectionTestMessage: String?
    @State private var connectionTestSuccess: Bool?

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

            Toggle("Always send credentials", isOn: $connectionConfig.alwaysSendBasicAuth)
                .font(.caption)
                .opacity(0.8)

            Toggle("Ignore SSL certificates", isOn: $connectionConfig.ignoreSSL)
                .font(.caption)
                .opacity(0.8)

            // 🧪 Test Connection Button
            HStack {
                Button {
                    Task {
                        await handleTestConnection()
                    }
                } label: {
                    if isTestingConnection {
                        ProgressView()
                    } else {
                        Label("Test Connection", systemSymbol: .arrowClockwise)
                    }
                }
                .disabled(isTestingConnection || connectionConfig.url.isEmpty)
                Spacer()
            }

            // 🟢/🔴 Feedback Message
            if let message = connectionTestMessage, let success = connectionTestSuccess {
                HStack {
                    Spacer()
                    Label(message, systemImage: success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundColor(success ? .green : .red)
                        .font(.caption2)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
    }

    private func handleTestConnection() async {
        isTestingConnection = true
        connectionTestMessage = nil
        connectionTestSuccess = nil

        do {
            try await testConnection()
            connectionTestMessage = "Connection successful"
            connectionTestSuccess = true
        } catch let urlError as URLError {
            connectionTestMessage = friendlyMessage(for: urlError)
            connectionTestSuccess = false
        } catch {
            connectionTestMessage = "Unexpected error: \(error.localizedDescription)"
            connectionTestSuccess = false
        }

        isTestingConnection = false
    }

    private func testConnection() async throws {
        try connectionConfig.url.testAsValidOpenHABURL()

        let connection = OpenAPIService(connectionConfiguration: connectionConfig)
        try await connection.getRootVersion()
    }

    private func friendlyMessage(for error: URLError) -> String {
        switch error.code {
        case .badURL:
            "The URL is invalid. Please check the format (e.g., http://192.168.2.1)."
        case .cannotFindHost:
            "Cannot find the server. Is the URL correct?"
        case .cannotConnectToHost:
            "Cannot connect to the server. Is it online?"
        case .notConnectedToInternet:
            "You appear to be offline. Check your internet connection."
        case .timedOut:
            "The connection timed out. Try again later."
        case .secureConnectionFailed:
            "SSL error. The connection couldn’t be established securely."
        default:
            error.localizedDescription
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
