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
import SwiftUI
import UIKit

struct ScreenSaverSettingsView: View {
    @State private var config = ScreenSaverConfiguration()
    private let fontOptions: [String] = ["", "Arial", "Helvetica Neue", "Courier New", "Menlo", "Avenir Next"]

    var body: some View {
        Form {
            enableSection
            appearanceSection
            timingSection
            fontSection
            animationSection
            brightnessSection
            testSection
        }
        .navigationTitle("Screen Saver")
        .onDisappear {
            let config = config //copy to make isolated var sendable
            Task { @MainActor in
                ScreenSaverManager.shared.updateConfiguration(config)
                // Persist to Preferences
                await Preferences.shared.modifyScreenSaverPreferences { prefs in
                    prefs.isEnabled = config.isEnabled
                    prefs.showsTime = config.showsTime
                    prefs.showsDate = config.showsDate
                    prefs.idleInterval = config.idleInterval
                    prefs.movementInterval = config.movementInterval
                    prefs.fontName = config.fontName ?? ""
                    prefs.timeFontRatio = Double(config.timeFontSizeRatio)
                    prefs.dateFontRatio = Double(config.dateFontRelativeSize)
                    prefs.enableDimming = config.enablesAutoDimming
                    prefs.dimLevel = Double(config.dimLevel)
                    prefs.wakeBrightness = Double(config.wakeBrightnessLevel)
                    prefs.showsSeconds = config.showsSeconds
                    prefs.use24Hour = config.uses24HourTime
                    prefs.fadeDuration = config.fadeDuration
                    prefs.restoreBrightness = config.restoresBrightness
                }
            }
        }
        .task { @MainActor in
            let prefs = await Preferences.shared.screensaverPreferences
            var config = ScreenSaverConfiguration()
            config.isEnabled = prefs.isEnabled
            config.showsTime = prefs.showsTime
            config.showsDate = prefs.showsDate
            config.idleInterval = prefs.idleInterval
            config.movementInterval = prefs.movementInterval
            config.fontName = prefs.fontName.isEmpty ? nil : prefs.fontName
            config.timeFontSizeRatio = CGFloat(prefs.timeFontRatio)
            config.dateFontRelativeSize = CGFloat(prefs.dateFontRatio)
            config.enablesAutoDimming = prefs.enableDimming
            config.dimLevel = CGFloat(prefs.dimLevel)
            config.wakeBrightnessLevel = CGFloat(prefs.wakeBrightness)
            config.showsSeconds = prefs.showsSeconds
            config.uses24HourTime = prefs.use24Hour
            config.fadeDuration = prefs.fadeDuration
            config.restoresBrightness = prefs.restoreBrightness
            changeConfig(config)
        }
    }

    private var fontBinding: Binding<String> {
        Binding(
            get: { config.fontName ?? "" },
            set: { config.fontName = $0.isEmpty ? nil : $0 }
        )
    }

    private var idleIntervalBinding: Binding<Int> {
        Binding(
            get: { Int(config.idleInterval) },
            set: { config.idleInterval = TimeInterval($0) }
        )
    }

    private var movementIntervalBinding: Binding<Int> {
        Binding(
            get: { Int(config.movementInterval) },
            set: { config.movementInterval = TimeInterval($0) }
        )
    }

    private var timeFontSizeBinding: Binding<Double> {
        Binding(
            get: { Double(config.timeFontSizeRatio) },
            set: { config.timeFontSizeRatio = CGFloat($0) }
        )
    }

    private var dateFontSizeBinding: Binding<Double> {
        Binding(
            get: { Double(config.dateFontRelativeSize) },
            set: { config.dateFontRelativeSize = CGFloat($0) }
        )
    }

    private var dimLevelBinding: Binding<Double> {
        Binding(
            get: { Double(config.dimLevel * 100) },
            set: { config.dimLevel = CGFloat($0) / 100 }
        )
    }

    private var wakeBrightnessBinding: Binding<Double> {
        Binding(
            get: { Double(config.wakeBrightnessLevel * 100) },
            set: { config.wakeBrightnessLevel = CGFloat($0) / 100 }
        )
    }

    @ViewBuilder
    private var enableSection: some View {
        Section {
            Toggle("Enable Screen Saver", isOn: $config.isEnabled)
        }
    }

    @ViewBuilder
    private var appearanceSection: some View {
        Section("Appearance") {
            Toggle("Show Time", isOn: $config.showsTime)
            Toggle("Show Date", isOn: $config.showsDate)
            Toggle("Show Seconds", isOn: $config.showsSeconds)
            Toggle("24-Hour Clock", isOn: $config.uses24HourTime)
            Picker("Font", selection: fontBinding) {
                ForEach(fontOptions, id: \.self) { name in
                    Text(name.isEmpty ? "Default" : name).tag(name)
                }
            }
        }
        .disabled(!config.isEnabled)
    }

    @ViewBuilder
    private var timingSection: some View {
        Section("Timing") {
            Stepper(value: idleIntervalBinding, in: 5 ... 600, step: 5) {
                Text("Idle Interval: \(Int(config.idleInterval)) s")
            }

            Stepper(value: movementIntervalBinding, in: 2 ... 60, step: 1) {
                Text("Movement Interval: \(Int(config.movementInterval)) s")
            }
        }
        .disabled(!config.isEnabled)
    }

    @ViewBuilder
    private var fontSection: some View {
        Section("Font Size") {
            VStack(alignment: .leading) {
                Text("Clock Size: \(Int(config.timeFontSizeRatio * 100)) %")
                    .font(.caption)
                Slider(value: timeFontSizeBinding, in: 0.05 ... 0.4, step: 0.01)
            }

            VStack(alignment: .leading) {
                Text("Date relative: \(Int(config.dateFontRelativeSize * 100)) %")
                    .font(.caption)
                Slider(value: dateFontSizeBinding, in: 0.1 ... 1.0, step: 0.05)
            }
        }
        .disabled(!config.isEnabled)
    }

    @ViewBuilder
    private var animationSection: some View {
        Section("Animation") {
            VStack(alignment: .leading) {
                Text("Fade Duration: \(String(format: "%.1f", config.fadeDuration)) s")
                    .font(.caption)
                Slider(value: $config.fadeDuration, in: 0.1 ... 3.0, step: 0.1)
            }
        }
        .disabled(!config.isEnabled)
    }

    @ViewBuilder
    private var brightnessSection: some View {
        Section("Brightness") {
            Toggle("Enable Dimming", isOn: $config.enablesAutoDimming)

            VStack(alignment: .leading) {
                Text("Dim Level: \(Int(config.dimLevel * 100)) %")
                    .font(.caption)
                Slider(value: dimLevelBinding, in: 0 ... 100, step: 1)
            }
            .disabled(!config.enablesAutoDimming)

            Toggle("Restore Previous Brightness on Wake", isOn: $config.restoresBrightness)
                .disabled(!config.enablesAutoDimming)

            VStack(alignment: .leading) {
                Text("Restore Brightness: \(Int(config.wakeBrightnessLevel * 100)) %")
                    .font(.caption)
                Slider(value: wakeBrightnessBinding, in: 0 ... 100, step: 1)
            }
            .disabled(!config.enablesAutoDimming || config.restoresBrightness)
        }
        .disabled(!config.isEnabled)
    }

    @ViewBuilder
    private var testSection: some View {
        Section {
            Button("Test Screen Saver") {
                if let keyWindow = UIApplication.shared.keyWindowActiveScene {
                    ScreenSaverManager.shared.startMonitoring(window: keyWindow, configuration: config)
                }
                ScreenSaverManager.shared.presentSaver(configuration: config)
            }
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
    NavigationStack {
        ScreenSaverSettingsView()
    }
}
