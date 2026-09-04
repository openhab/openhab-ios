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
            let c = config
            ScreenSaverManager.shared.updateConfiguration(c)
            Task {
                await Preferences.shared.saveScreenSaverSettings(ScreenSaverPreferences(
                    isEnabled: c.isEnabled,
                    showsTime: c.showsTime,
                    showsDate: c.showsDate,
                    idleInterval: c.idleInterval,
                    movementInterval: c.movementInterval,
                    fontName: c.fontName ?? "",
                    timeFontSizeRatio: Double(c.timeFontSizeRatio),
                    dateFontRelativeSize: Double(c.dateFontRelativeSize),
                    enablesAutoDimming: c.enablesAutoDimming,
                    dimLevel: Double(c.dimLevel),
                    wakeBrightnessLevel: Double(c.wakeBrightnessLevel),
                    showsSeconds: c.showsSeconds,
                    uses24HourTime: c.uses24HourTime,
                    fadeDuration: c.fadeDuration,
                    restoresBrightness: c.restoresBrightness
                ))
            }
        }
        .task { @MainActor in
            let ssPrefs = await Preferences.shared.screensaverPreferences()
            var c = ScreenSaverConfiguration()
            c.isEnabled = ssPrefs.isEnabled
            c.showsTime = ssPrefs.showsTime
            c.showsDate = ssPrefs.showsDate
            c.idleInterval = ssPrefs.idleInterval
            c.movementInterval = ssPrefs.movementInterval
            c.fontName = ssPrefs.fontName.isEmpty ? nil : ssPrefs.fontName
            c.timeFontSizeRatio = CGFloat(ssPrefs.timeFontSizeRatio)
            c.dateFontRelativeSize = CGFloat(ssPrefs.dateFontRelativeSize)
            c.enablesAutoDimming = ssPrefs.enablesAutoDimming
            c.dimLevel = CGFloat(ssPrefs.dimLevel)
            c.wakeBrightnessLevel = CGFloat(ssPrefs.wakeBrightnessLevel)
            c.showsSeconds = ssPrefs.showsSeconds
            c.uses24HourTime = ssPrefs.uses24HourTime
            c.fadeDuration = ssPrefs.fadeDuration
            c.restoresBrightness = ssPrefs.restoresBrightness
            changeConfig(c)
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

    private var enableSection: some View {
        Section {
            Toggle("Enable Screen Saver", isOn: $config.isEnabled)
        }
    }

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

    private var fontSection: some View {
        Section("Font Size") {
            VStack(alignment: .leading) {
                Text("Clock Size: \(Double(config.timeFontSizeRatio).formatted(.percent.precision(.fractionLength(0))))")
                    .font(.caption)
                    .monospacedDigit()
                Slider(value: timeFontSizeBinding, in: 0.05 ... 0.4, step: 0.01)
            }

            VStack(alignment: .leading) {
                Text("Relative Date: \(Double(config.dateFontRelativeSize).formatted(.percent.precision(.fractionLength(0))))")
                    .font(.caption)
                    .monospacedDigit()
                Slider(value: dateFontSizeBinding, in: 0.1 ... 1.0, step: 0.05)
            }
        }
        .disabled(!config.isEnabled)
    }

    private var animationSection: some View {
        Section("Animation") {
            VStack(alignment: .leading) {
                Text("Fade Duration: \(String(format: "%.1f", config.fadeDuration)) s")
                    .font(.caption)
                    .monospacedDigit()
                Slider(value: $config.fadeDuration, in: 0.1 ... 3.0, step: 0.1)
            }
        }
        .disabled(!config.isEnabled)
    }

    private var brightnessSection: some View {
        Section("Brightness") {
            Toggle("Enable Dimming", isOn: $config.enablesAutoDimming)

            VStack(alignment: .leading) {
                Text("Dim Level: \(Double(config.dimLevel).formatted(.percent.precision(.fractionLength(0))))")
                    .font(.caption)
                    .monospacedDigit()
                Slider(value: dimLevelBinding, in: 0 ... 100, step: 1)
            }
            .disabled(!config.enablesAutoDimming)

            Toggle("Restore Previous Brightness on Wake", isOn: $config.restoresBrightness)
                .disabled(!config.enablesAutoDimming)

            VStack(alignment: .leading) {
                Text("Restore Brightness: \(Double(config.wakeBrightnessLevel).formatted(.percent.precision(.fractionLength(0))))")
                    .font(.caption)
                    .monospacedDigit()
                Slider(value: wakeBrightnessBinding, in: 0 ... 100, step: 1)
            }
            .disabled(!config.enablesAutoDimming || config.restoresBrightness)
        }
        .disabled(!config.isEnabled)
    }

    private var testSection: some View {
        Section {
            Button("Test Screen Saver") {
                ScreenSaverManager.shared.startMonitoring(configuration: config)
                ScreenSaverManager.shared.presentSaver(configuration: config)
            }
        }
    }

    private func changeConfig(_ config: ScreenSaverConfiguration) {
        self.config = config
    }
}


#Preview {
    NavigationStack {
        ScreenSaverSettingsView()
    }
}
