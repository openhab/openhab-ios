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

import CommonUI
import OpenHABCore
import os.log
import SFSafeSymbols
import SwiftUI

struct ColorTemperaturePickerRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @State private var selectedTemperature: Double = 2700 // Default warm white

    private let logger = Logger(subsystem: "org.openhab", category: "ColorTemperaturePickerRowView")

    // Use widget's min/max values, similar to Android implementation
    private var minTemperature: Double {
        max(widget.minValue, 1000)
    }

    private var maxTemperature: Double {
        min(widget.maxValue, 10000)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Label
            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
            }

            // Color temperature slider with gradient background
            VStack(spacing: 8) {
                HStack {
                    // Warm indicator
                    Image(systemSymbol: .sunMinFill)
                        .foregroundColor(.orange)
                        .font(.caption)

                    // Slider with custom gradient track
                    ZStack(alignment: .leading) {
                        // Gradient background representing color temperature spectrum
                        // Using realistic color temperature colors like Android app
                        LinearGradient(
                            colors: colorTemperatureGradient(),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: 6)
                        .cornerRadius(3)

                        // Actual slider
                        Slider(
                            value: $selectedTemperature,
                            in: minTemperature ... maxTemperature,
                            step: 100
                        ) { _ in
                            sendTemperatureCommand()
                        }
                        .accentColor(.clear) // Hide default slider track
                    }

                    // Cool indicator
                    Image(systemSymbol: .snowflake)
                        .foregroundColor(.blue)
                        .font(.caption)
                }

                // Temperature value display
                HStack {
                    Text("\(Int(selectedTemperature))K")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Temperature description
                    Text(temperatureDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Widget value (current state)
            if let labelValue = widget.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .font(.caption)
                    .foregroundColor(widget.valuecolor.isEmpty ? .secondary : Color(fromString: widget.valuecolor))
            }
        }
        .onAppear {
            loadCurrentTemperature()
        }
    }

    private var temperatureDescription: String {
        switch selectedTemperature {
        case 1000 ..< 2000: "Candlelight"
        case 2000 ..< 2700: "Very Warm"
        case 2700 ..< 3000: "Warm White"
        case 3000 ..< 4000: "Soft White"
        case 4000 ..< 5000: "Cool White"
        case 5000 ..< 6500: "Daylight"
        case 6500 ..< 8000: "Cool Daylight"
        default: "Very Cool"
        }
    }

    // Generate gradient colors similar to Android implementation
    private func colorTemperatureGradient() -> [Color] {
        let steps = 20
        let colors = (0 ..< steps).map { step in
            let temperature = minTemperature + (maxTemperature - minTemperature) * Double(step) / Double(steps - 1)
            return temperatureToColor(temperature)
        }
        return colors
    }

    private func loadCurrentTemperature() {
        guard let state = widget.item?.state, !state.isEmpty else { return }

        // Parse color temperature directly from Kelvin value (like Android app)
        if let kelvin = Double(state) {
            selectedTemperature = kelvin.clamped(to: minTemperature ... maxTemperature)
        }
    }

    private func sendTemperatureCommand() {
        // Send temperature directly as Kelvin value (like Android app)
        let command = "\(Int(selectedTemperature))"

        logger.info("Sending color temperature command: \(command)K")
        widget.sendCommand(command)
    }

    // Convert temperature in Kelvin to approximate RGB color
    private func temperatureToColor(_ kelvin: Double) -> Color {
        let temp = kelvin / 100

        var red: Double = 0
        var green: Double = 0
        var blue: Double = 0

        // Calculate red
        if temp <= 66 {
            red = 255
        } else {
            red = temp - 60
            red = 329.698727446 * pow(red, -0.1332047592)
            red = red.clamped(to: 0 ... 255)
        }

        // Calculate green
        if temp <= 66 {
            green = temp
            green = 99.4708025861 * log(green) - 161.1195681661
            green = green.clamped(to: 0 ... 255)
        } else {
            green = temp - 60
            green = 288.1221695283 * pow(green, -0.0755148492)
            green = green.clamped(to: 0 ... 255)
        }

        // Calculate blue
        if temp >= 66 {
            blue = 255
        } else if temp <= 19 {
            blue = 0
        } else {
            blue = temp - 10
            blue = 138.5177312231 * log(blue) - 305.0447927307
            blue = blue.clamped(to: 0 ... 255)
        }

        return Color(
            red: red / 255.0,
            green: green / 255.0,
            blue: blue / 255.0
        )
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[13]
    ColorTemperaturePickerRowView(widget: widget)
        .padding()
}
