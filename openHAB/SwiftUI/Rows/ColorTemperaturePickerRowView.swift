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

import CommonUI
import OpenHABCore
import os.log
import SFSafeSymbols
import SwiftUI

struct CustomSliderView: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let onEditingChanged: () -> Void

    @State private var lastSendTime: Date = .distantPast

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let normalized = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let xPos = normalized * width

            ZStack(alignment: .leading) {
                Color.clear

                Circle()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.white)
                    .shadow(radius: 1)
                    .overlay(Circle().stroke(Color.gray.opacity(0.6), lineWidth: 1))
                    .position(x: xPos, y: height / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                let location = gesture.location.x.clamped(to: 0 ... width)
                                let raw = Double(location / width) * (range.upperBound - range.lowerBound) + range.lowerBound
                                let stepped = (raw / step).rounded() * step
                                value = stepped.clamped(to: range)
                                let now = Date()
                                if now.timeIntervalSince(lastSendTime) > 0.2 {
                                    lastSendTime = now
                                    onEditingChanged()
                                }
                            }
                            .onEnded { _ in
                                onEditingChanged()
                            }
                    )
            }
        }
    }
}

struct ColorTemperaturePickerRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @State private var selectedTemperature: Double = 2700 // Default warm white
    @EnvironmentObject var viewModel: SitemapPageViewModel

    private var colorTemperatureCommandKey: String {
        "color-temperature-\(widget.widgetId)"
    }

    private let logger = Logger(subsystem: "org.openhab", category: "ColorTemperaturePickerRowView")
    private var displayState: WidgetDisplayState { widget.displayState }

    // Use widget's min/max values, similar to Android implementation
    private var minTemperature: Double {
        max(displayState.minValue, 1000)
    }

    private var maxTemperature: Double {
        min(displayState.maxValue, 10000)
    }

    var body: some View {
        HStack(alignment: .top) {
            IconView(widget: widget)
                .frame(width: 32, height: 32)

            VStack(spacing: 8) {
                HStack {
                    if !displayState.labelText.isEmpty {
                        let labelText = displayState.labelText
                        Text(labelText)
                            .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
                            .lineLimit(1)
                    }

                    Spacer()

                    // Temperature value display
                    HStack {
                        Text("\(Int(selectedTemperature))K")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(" - ")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Temperature description
                        Text(temperatureDescription)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Color temperature slider with gradient background
                HStack {
                    // Warm indicator
                    Image(systemSymbol: .sunMinFill)
                        .foregroundStyle(.orange)
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
                        .frame(height: 10)
                        .clipShape(.rect(cornerRadius: 3))

                        // Actual slider
                        CustomSliderView(
                            value: $selectedTemperature,
                            range: minTemperature ... maxTemperature,
                            step: 100
                        ) {
                            sendTemperatureCommand()
                        }
                        .frame(height: 28)
                        .disabled(widget.readOnly ?? false)
                    }

                    // Cool indicator
                    Image(systemSymbol: .snowflake)
                        .foregroundStyle(.blue)
                        .font(.caption)
                }
            }
        }
        .onAppear {
            selectedTemperature = loadCurrentTemperature(state: displayState.effectiveState) ?? 2700
        }
        .onChange(of: displayState.effectiveState) { newState in
            selectedTemperature = loadCurrentTemperature(state: newState) ?? 2700
        }
        .onDisappear {
            if let item = widget.item {
                viewModel.cancelPendingCommand(for: item, key: colorTemperatureCommandKey)
            } else {
                viewModel.cancelPendingCommand(for: widget, key: colorTemperatureCommandKey)
            }
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
    private func colorTemperatureGradient(steps: Int = 20) -> [Color] {
        stride(from: minTemperature, through: maxTemperature, by: (maxTemperature - minTemperature) / Double(steps)).map { Color(temperature: $0) }
    }

    private func loadCurrentTemperature(state: String?) -> Double? {
        guard let state, !state.isEmpty else { return nil }

        // Parse color temperature directly from Kelvin value (like Android app)
        let kelvin = state.parseAsNumber().value
        return kelvin.clamped(to: minTemperature ... maxTemperature)
    }

    private func sendTemperatureCommand() {
        // Send temperature directly as Kelvin value (like Android app)
        let command = "\(Int(selectedTemperature))"

        logger.info("Sending color temperature command: \(command)K")
        viewModel.sendCommand(
            command,
            for: widget,
            policy: WidgetCommandDefaults.slider,
            key: colorTemperatureCommandKey
        )
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[13]
    VStack {
        ColorTemperaturePickerRowView(widget: widget)
            .padding()
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
