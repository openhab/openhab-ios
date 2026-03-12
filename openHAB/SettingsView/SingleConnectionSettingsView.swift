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

struct SpinningSymbol: View {
    @State private var isAnimating = false

    var body: some View {
        Image(systemSymbol: .arrowTriangle2Circlepath)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(
                Animation.linear(duration: 1.0)
                    .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

struct SingleConnectionSettingsView: View {
    var headerText: String
    var isLocalConnection = false

    @Binding var connectionConfig: ConnectionConfiguration
    var showNotificationToggle: Bool

    @State private var isTestingConnection = false
    @State private var connectionTestMessage: String?
    @State private var connectionTestSuccess: Bool?

    @State private var isPresentingDiscoverySheet = false

    var body: some View {
        Section(header: Text(headerText)) {
            VStack(alignment: .leading) {
                LabeledContent {
                    Spacer()
                    TextField("URL", text: $connectionConfig.url)
                        .textContentType(.URL) // Helps iOS identify it as a URL field
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .fixedSize()
                        .font(.system(.caption))
                } label: {
                    HStack {
                        Text("URL")
                        if isLocalConnection {
                            Button(action: {
                                isPresentingDiscoverySheet = true
                            }, label: {
                                Image(systemSymbol: .bonjour)
                                    .font(.callout) // Smaller than default .body
                                    .imageScale(.small)
                            })
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        if isTestingConnection {
                            SpinningSymbol()
                                .scaleEffect(0.8)
                        } else {
                            Button {
                                Task {
                                    await handleTestConnection()
                                }
                            } label: {
                                Image(systemSymbol: .wifiCircle)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)
                            .disabled(connectionConfig.url.isEmpty)
                            .help("Test Connection")
                        }
                    }
                    if connectionConfig.url.isEmpty {
                        Text("Enter URL of remote server")
                    }
                }
                .sheet(isPresented: $isPresentingDiscoverySheet) {
                    BonjourDiscoverySheet(isPresented: $isPresentingDiscoverySheet, connectionConfig: $connectionConfig)
                }

                if let message = connectionTestMessage, let success = connectionTestSuccess {
                    HStack(spacing: 4) {
                        Image(systemSymbol: success ? .checkmarkCircle : .xmarkOctagon)
                            .foregroundStyle(success ? .green : .red)
                        Text(message)
                            .foregroundStyle(success ? .green : .red)
                            .font(.caption2)
                    }
                    .transition(.opacity)
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
                    Text("Enter username for server, if required")
                }
            }

            LabeledContent {
                AnimatedSecureTextField(text: $connectionConfig.password, titleKey: String(localized: "Password"))
                    .fixedSize()
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true) //   or  .autocorrectionDisabled(true) ??
                    .font(.system(.caption))
                    .textContentType(.password) // Associates with AutoFill
            } label: {
                Text("Password")
                if connectionConfig.password.isEmpty {
                    Text("Enter password for server")
                }
            }

            Toggle("Always send credentials", isOn: $connectionConfig.alwaysSendBasicAuth)
                .font(.caption)
                .opacity(0.8)

            Toggle("Ignore SSL certificates", isOn: $connectionConfig.ignoreSSL)
                .font(.caption)
                .opacity(0.8)

            if showNotificationToggle {
                Toggle("openHAB Cloud Service", isOn: $connectionConfig.supportsNotifications)
                    .font(.caption)
                    .opacity(0.8)
            }
        }
    }

    private func handleTestConnection() async {
        isTestingConnection = true
        connectionTestMessage = nil
        connectionTestSuccess = nil

        do {
            try await testConnection()
            connectionTestMessage = String(localized: "Connection successful")
            connectionTestSuccess = true
        } catch is CancellationError {
            connectionTestMessage = String(localized: "Cancellation occurred")
            connectionTestSuccess = false
        } catch let error as DecodingError {
            connectionTestMessage = String(localized: "Unexpected error: \(error.localizedDescription)")
            connectionTestSuccess = false
        } catch {
            if let urlError = OpenAPIErrorInspector.underlyingURLError(from: error) {
                connectionTestMessage = friendlyMessage(for: urlError)
            } else if let message = OpenAPIErrorInspector.underlyingErrorDescription(from: error) {
                connectionTestMessage = message
            } else if let openAPIError = error as? OpenAPIServiceError {
                connectionTestMessage = openAPIError.localizedDescription
            } else if let urlError = error as? URLError {
                connectionTestMessage = friendlyMessage(for: urlError)
            } else {
                connectionTestMessage = "Unexpected error: \(error.localizedDescription)"
            }
            connectionTestSuccess = false
        } catch let openAPIError as OpenAPIServiceError {
            connectionTestMessage = "\(openAPIError.localizedDescription)"
            connectionTestSuccess = false
        } catch let urlError as URLError {
            connectionTestMessage = friendlyMessage(for: urlError)
            connectionTestSuccess = false
        } catch {
            connectionTestMessage = String(localized: "Unexpected error: \(error.localizedDescription)")
            connectionTestSuccess = false
        }

        isTestingConnection = false
    }

    func testConnection() async throws {
        try connectionConfig.url.testAsValidOpenHABURL()

        let connection = try OpenAPIService(connectionConfiguration: connectionConfig, serviceConfiguration: .shortTerm)
        try await connection.getRootVersion()
    }

    private func friendlyMessage(for error: URLError) -> String {
        switch error.code {
        case .badURL:
            String(localized: "The URL is invalid. Please check the format (e.g., http://192.168.2.1:8080).")
        case .cannotFindHost:
            String(localized: "Cannot find the server. Is the URL correct?")
        case .cannotConnectToHost:
            String(localized: "Cannot connect to the server. Is it online?")
        case .notConnectedToInternet:
            String(localized: "You appear to be offline. Check your internet connection.")
        case .timedOut:
            String(localized: "The connection timed out. Try again later.")
        case .secureConnectionFailed:
            String(localized: "SSL error. The connection couldn’t be established securely.")
        default:
            error.localizedDescription
        }
    }
}

// **TODO Migrate to @Previewable on iOS 17
#Preview {
    struct PreviewWrapper: View {
        @State var connectionConfig = ConnectionConfiguration(
            url: "https://openhab.local:8443",
            username: "user",
            password: "password123"
        )

        var body: some View {
            NavigationStack {
                Form {
                    SingleConnectionSettingsView(headerText: String(localized: "Connection Settings for local server"), connectionConfig: $connectionConfig, showNotificationToggle: false)
                }
            }
        }
    }
    return PreviewWrapper()
}
