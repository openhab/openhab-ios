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

struct ScreenSaverSettingsView: View {
    @State private var config = ScreenSaverConfiguration()

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

                VStack(alignment: .leading) {
                    Text("Dim Level: \(Int(config.dimLevel * 100)) %")
                        .font(.caption)
                    Slider(value: Binding(
                        get: { Double(config.dimLevel * 100) },
                        set: { config.dimLevel = CGFloat($0) / 100 }
                    ), in: 0 ... 100, step: 1)
                }
                .disabled(!config.enablesAutoDimming)

                Toggle("Restore Previous Brightness on Wake", isOn: Binding(
                    get: { config.restoresBrightness },
                    set: { config.restoresBrightness = $0 }
                )).disabled(!config.enablesAutoDimming)

                VStack(alignment: .leading) {
                    Text("Restore Brightness: \(Int(config.wakeBrightnessLevel * 100)) %")
                        .font(.caption)
                    Slider(value: Binding(
                        get: { Double(config.wakeBrightnessLevel * 100) },
                        set: { config.wakeBrightnessLevel = CGFloat($0) / 100 }
                    ), in: 0 ... 100, step: 1)
                }
                .disabled(!config.enablesAutoDimming || config.restoresBrightness)
            }
            .disabled(!config.isEnabled)

            Section {
                Button("Test Screen Saver") {
                    if let keyWindow = UIApplication.shared.keyWindowActiveScene {
                        // Ensure the manager knows about the current key window in case monitoring was not started yet.
                        ScreenSaverManager.shared.startMonitoring(window: keyWindow, configuration: config)
                    }
                    ScreenSaverManager.shared.presentSaver(configuration: config)
                }
            }
        }
        .navigationTitle("Screen Saver")
        .onDisappear {
            ScreenSaverManager.shared.updateConfiguration(config)
            // Persist to Preferences
            Preferences.shared.screensaverEnabled = config.isEnabled
            Preferences.shared.screensaverShowsTime = config.showsTime
            Preferences.shared.screensaverShowsDate = config.showsDate
            Preferences.shared.screensaverIdleInterval = config.idleInterval
            Preferences.shared.screensaverMovementInterval = config.movementInterval
            Preferences.shared.screensaverFontName = config.fontName ?? ""
            Preferences.shared.screensaverTimeFontRatio = Double(config.timeFontSizeRatio)
            Preferences.shared.screensaverDateFontRatio = Double(config.dateFontRelativeSize)
            Preferences.shared.screensaverEnableDimming = config.enablesAutoDimming
            Preferences.shared.screensaverDimLevel = Double(config.dimLevel)
            Preferences.shared.screensaverWakeBrightness = Double(config.wakeBrightnessLevel)
            Preferences.shared.screensaverShowsSeconds = config.showsSeconds
            Preferences.shared.screensaverUse24Hour = config.uses24HourTime
            Preferences.shared.screensaverFadeDuration = config.fadeDuration
            Preferences.shared.screensaverRestoreBrightness = config.restoresBrightness
        }
        .task { @Preferences in
            var config = ScreenSaverConfiguration()
            config.isEnabled = Preferences.shared.screensaverEnabled
            config.showsTime = Preferences.shared.screensaverShowsTime
            config.showsDate = Preferences.shared.screensaverShowsDate
            config.idleInterval = Preferences.shared.screensaverIdleInterval
            config.movementInterval = Preferences.shared.screensaverMovementInterval
            config.fontName = Preferences.shared.screensaverFontName.isEmpty ? nil : Preferences.shared.screensaverFontName
            config.timeFontSizeRatio = CGFloat(Preferences.shared.screensaverTimeFontRatio)
            config.dateFontRelativeSize = CGFloat(Preferences.shared.screensaverDateFontRatio)
            config.enablesAutoDimming = Preferences.shared.screensaverEnableDimming
            config.dimLevel = CGFloat(Preferences.shared.screensaverDimLevel)
            config.wakeBrightnessLevel = CGFloat(Preferences.shared.screensaverWakeBrightness)
            config.showsSeconds = Preferences.shared.screensaverShowsSeconds
            config.uses24HourTime = Preferences.shared.screensaverUse24Hour
            config.fadeDuration = Preferences.shared.screensaverFadeDuration
            config.restoresBrightness = Preferences.shared.screensaverRestoreBrightness
            await changeConfig(config)
        }
    }

    private func changeConfig(_ config: ScreenSaverConfiguration) {
        self.config = config
    }
}

extension UIApplication {
    var keyWindowActiveScene: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows
            .first { $0.isKeyWindow }
    }
}

#Preview {
    NavigationView {
        ScreenSaverSettingsView()
    }
}
