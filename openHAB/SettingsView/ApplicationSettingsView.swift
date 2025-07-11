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
import SwiftUI
import UIKit

struct ApplicationSettingsView: View {
    @Binding var settingsIdleOff: Bool

    private let logger = Logger(subsystem: "org.openhab.app", category: "ApplicationSettingsView")

    var body: some View {
        Section(header: Text(LocalizedStringKey("application_settings"))) {
            Toggle("Disable Idle Timeout", isOn: $settingsIdleOff)
                .onChange(of: settingsIdleOff) { newValue in
                    if let keyWindow = UIApplication.shared.windows.first {
                        if newValue {
                            ScreenSaverManager.shared.startMonitoring(window: keyWindow)
                        } else {
                            NotificationCenter.default.post(name: .wakeScreenSaver, object: nil)
                        }
                    }
                }

            // Screen Saver settings available only when idle timeout is disabled
            NavigationLink("Screen Saver Settings") {
                ScreenSaverSettingsView()
            }
            .disabled(!settingsIdleOff)

            Toggle("Hide Status Bar", isOn: Binding(
                get: { Preferences.hideStatusBar },
                set: { Preferences.hideStatusBar = $0; UIApplication.shared.windows.first?.rootViewController?.setNeedsStatusBarAppearanceUpdate() }
            ))

            NavigationLink("Client Certificates") {
                ClientCertificatesView()
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var idleOff = false

        var body: some View {
            Form {
                ApplicationSettingsView(
                    settingsIdleOff: $idleOff
                )
            }
        }
    }

    return PreviewWrapper()
}
