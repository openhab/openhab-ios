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
import os
import SwiftUI
import UIKit

struct ApplicationSettingsView: View {
    @Binding var settingsIdleOff: Bool
    @Binding var settingsSSECommandItem: String

    @State private var selectedItemName: String?

    var body: some View {
        Section(header: Text(LocalizedStringKey("application_settings"))) {
            Toggle("Disable Idle Timeout", isOn: $settingsIdleOff)

            NavigationLink("Screen Saver Settings") {
                ScreenSaverSettingsView()
            }

            Toggle("Hide Status Bar", isOn: Binding(
                get: { Preferences.shared.hideStatusBar },
                set: { Preferences.shared.hideStatusBar = $0; UIApplication.shared.keyWindowActiveScene?.rootViewController?.setNeedsStatusBarAppearanceUpdate() }
            ))

            NavigationLink("Client Certificates") {
                ClientCertificatesView()
            }

            NavigationLink("Accepted Server Certificates") {
                ServerCertificatesView()
            }

            NavigationLink {
                ItemSelectionView(selectedItemName: $selectedItemName)
            } label: {
                Text("Command Item \(selectedItemName?.isEmpty == false ? "(\(selectedItemName ?? ""))" : "")")
            }
        }
        .onChange(of: selectedItemName) { _, newSelection in
            handleItemSelectionChange(newSelection)
        }
        .onAppear {
            selectedItemName = settingsSSECommandItem
        }
    }

    private func handleItemSelectionChange(_ selected: String?) {
        if let selected {
            settingsSSECommandItem = selected
        } else {
            settingsSSECommandItem = ""
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var idleOff = false
        @State private var sseCommandItem = ""
        var body: some View {
            Form {
                ApplicationSettingsView(
                    settingsIdleOff: $idleOff,
                    settingsSSECommandItem: $sseCommandItem
                )
            }
        }
    }

    return PreviewWrapper()
}
