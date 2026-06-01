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

#Preview {
    @Previewable @State var demoMode = false
    @Previewable @State var connectionConfig1 = ConnectionConfiguration(
        url: "https://openhab.local:8443",
        username: "user",
        password: "password123"
    )
    @Previewable @State var connectionConfig2 = ConnectionConfiguration(
        url: "http://192.168.2.1",
        username: "user",
        password: "password123"
    )

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
