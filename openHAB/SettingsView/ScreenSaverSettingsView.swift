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
import SwiftUI
import UIKit

extension UIApplication {
    var keyWindowActiveScene: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows
            .first { $0.isKeyWindow }
    }
}

struct ScreenSaverSettingsView: View {
    @State private var config: ScreenSaverConfiguration = {
        var c = ScreenSaverConfiguration()
        c.isEnabled = Preferences.screensaverEnabled
        c.showsTime = Preferences.screensaverShowsTime
        c.showsDate = Preferences.screensaverShowsDate
        c.idleInterval = Preferences.screensaverIdleInterval
        c.movementInterval = Preferences.screensaverMovementInterval
        c.fontName = Preferences.screensaverFontName.isEmpty ? nil : Preferences.screensaverFontName
        c.timeFontSizeRatio = CGFloat(Preferences.screensaverTimeFontRatio)
        c.dateFontRelativeSize = CGFloat(Preferences.screensaverDateFontRatio)
        c.enablesAutoDimming = Preferences.screensaverEnableDimming
        c.dimmingOffset = CGFloat(Preferences.screensaverDimmingOffset)
        c.showsSeconds = Preferences.screensaverShowsSeconds
        c.uses24HourTime = Preferences.screensaverUse24Hour
        c.fadeDuration = Preferences.screensaverFadeDuration
        return c
    }()

    var body: some View {
        Form {
            Section {
                Toggle("Enable Screen Saver", isOn: Binding(
                    get: { config.isEnabled },
                    set: { config.isEnabled = $0 }
                ))
            }

            Section("Appearance") {
                Toggle("Show Time", isOn: Binding(
                    get: { config.showsTime },
                    set: { newVal in config.showsTime = newVal }
                ))

                Toggle("Show Date", isOn: Binding(
                    get: { config.showsDate },
                    set: { newVal in config.showsDate = newVal }
                ))

                Toggle("Show Seconds", isOn: Binding(
                    get: { config.showsSeconds },
                    set: { config.showsSeconds = $0 }
                ))

                Toggle("24-Hour Clock", isOn: Binding(
                    get: { config.uses24HourTime },
                    set: { config.uses24HourTime = $0 }
                ))

                let fontOptions: [String] = ["", "Arial", "Helvetica Neue", "Courier New", "Menlo", "Avenir Next"]
                Picker("Font", selection: Binding(
                    get: { config.fontName ?? "" },
                    set: { config.fontName = $0.isEmpty ? nil : $0 }
                )) {
                    ForEach(fontOptions, id: \.self) { name in
                        Text(name.isEmpty ? "Default" : name).tag(name)
                    }
                }
            }
            .disabled(!config.isEnabled)

            Section("Timing") {
                Stepper(value: Binding(
                    get: { Int(config.idleInterval) },
                    set: { config.idleInterval = TimeInterval($0) }
                ), in: 5 ... 600, step: 5) {
                    Text("Idle Interval: \(Int(config.idleInterval)) s")
                }

                Stepper(value: Binding(
                    get: { Int(config.movementInterval) },
                    set: { config.movementInterval = TimeInterval($0) }
                ), in: 2 ... 60, step: 1) {
                    Text("Movement Interval: \(Int(config.movementInterval)) s")
                }
            }
            .disabled(!config.isEnabled)

            Section("Font Size") {
                VStack(alignment: .leading) {
                    Text("Clock Size: \(Int(config.timeFontSizeRatio * 100)) %")
                        .font(.caption)
                    Slider(value: Binding(
                        get: { Double(config.timeFontSizeRatio) },
                        set: { config.timeFontSizeRatio = CGFloat($0) }
                    ), in: 0.05 ... 0.4, step: 0.01)
                }

                VStack(alignment: .leading) {
                    Text("Date relative: \(Int(config.dateFontRelativeSize * 100)) %")
                        .font(.caption)
                    Slider(value: Binding(
                        get: { Double(config.dateFontRelativeSize) },
                        set: { config.dateFontRelativeSize = CGFloat($0) }
                    ), in: 0.1 ... 1.0, step: 0.05)
                }
            }
            .disabled(!config.isEnabled)

            Section("Animation") {
                VStack(alignment: .leading) {
                    Text("Fade Duration: \(String(format: "%.1f", config.fadeDuration)) s")
                        .font(.caption)
                    Slider(value: Binding(
                        get: { config.fadeDuration },
                        set: { config.fadeDuration = $0 }
                    ), in: 0.1 ... 3.0, step: 0.1)
                }
            }
            .disabled(!config.isEnabled)

            Section("Brightness") {
                Toggle("Enable Dimming", isOn: Binding(
                    get: { config.enablesAutoDimming },
                    set: { config.enablesAutoDimming = $0 }
                ))

                Slider(value: Binding(
                    get: { Double(config.dimmingOffset) },
                    set: { config.dimmingOffset = CGFloat($0) }
                ), in: -0.9 ... 0.5, step: 0.05) {
                    Text("Dim Offset: \(String(format: "%.2f", config.dimmingOffset))")
                }
            }
            .disabled(!config.isEnabled)
        }
        .navigationTitle("Screen Saver")
        .onDisappear {
            ScreenSaverManager.shared.updateConfiguration(config)
            // Persist to Preferences
            Preferences.screensaverEnabled = config.isEnabled
            Preferences.screensaverShowsTime = config.showsTime
            Preferences.screensaverShowsDate = config.showsDate
            Preferences.screensaverIdleInterval = config.idleInterval
            Preferences.screensaverMovementInterval = config.movementInterval
            Preferences.screensaverFontName = config.fontName ?? ""
            Preferences.screensaverTimeFontRatio = Double(config.timeFontSizeRatio)
            Preferences.screensaverDateFontRatio = Double(config.dateFontRelativeSize)
            Preferences.screensaverEnableDimming = config.enablesAutoDimming
            Preferences.screensaverDimmingOffset = Double(config.dimmingOffset)
            Preferences.screensaverShowsSeconds = config.showsSeconds
            Preferences.screensaverUse24Hour = config.uses24HourTime
            Preferences.screensaverFadeDuration = config.fadeDuration
        }
    }
}

#Preview {
    NavigationView {
        ScreenSaverSettingsView()
    }
}
