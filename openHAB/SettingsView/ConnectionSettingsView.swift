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

struct ConnectionSettingsView: View {
    @Binding var settingsDemomode: Bool
    @Binding var localConnectionConfiguration: ConnectionConfiguration
    @Binding var remoteConnectionConfiguration: ConnectionConfiguration

    var body: some View {
        Toggle("Demo Mode", isOn: $settingsDemomode)
            .accessibilityIdentifier("Demo Mode")

        if !settingsDemomode {
            Group {
                SingleConnectionSettingsView(headerText: String(localized: "Local server"), isLocalConnection: true, connectionConfig: $localConnectionConfiguration, showNotificationToggle: false)
                SingleConnectionSettingsView(headerText: String(localized: "Remote server"), connectionConfig: $remoteConnectionConfiguration, showNotificationToggle: true)
            }
        }
    }
}

// **TODO Migrate to @Previewable on iOS 17
#Preview {
    struct PreviewWrapper: View {
        @State var demoMode = false
        @State var localUrl = "https://openhab.local:8443"
        @State var remoteUrl = "https://myopenhab.org"
        @State var username = "user"
        @State var password = "password123"
        @State var alwaysSendCreds = true

        @State var connectionConfig1 = ConnectionConfiguration(
            url: "https://openhab.local:8443",
            username: "user",
            password: "password123"
        )
        @State var connectionConfig2 = ConnectionConfiguration(
            url: "http://192.168.2.1",
            username: "user",
            password: "password123"
        )

        var body: some View {
            NavigationStack {
                Form {
                    ConnectionSettingsView(
                        settingsDemomode: $demoMode,
                        localConnectionConfiguration: $connectionConfig1,
                        remoteConnectionConfiguration: $connectionConfig2
                    )
                }
            }
        }
    }
    return PreviewWrapper()
}
