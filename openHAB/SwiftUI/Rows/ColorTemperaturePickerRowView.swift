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

struct CustomSliderView: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let onEditingChanged: () -> Void

    @GestureState private var dragOffset: CGSize = .zero

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
                    .foregroundColor(.white)
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

    private let logger = Logger(subsystem: "org.openhab", category: "ColorTemperaturePickerRowView")

    // Use widget's min/max values, similar to Android implementation
    private var minTemperature: Double {
        max(widget.minValue, 1000)
    }

    private var maxTemperature: Double {
        min(widget.maxValue, 10000)
    }

    var body: some View {
        HStack(alignment: .top) {
            IconView(widget: widget)
                .frame(width: 24, height: 24)

            VStack(spacing: 8) {
                HStack {
                    if let labelText = widget.labelText, !labelText.isEmpty {
                        Text(labelText)
                            .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
                    }

                    Spacer()

                    // Temperature value display
                    HStack {
                        Text("\(Int(selectedTemperature))K")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(" - ")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // Temperature description
                        Text(temperatureDescription)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Color temperature slider with gradient background
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
                        .frame(height: 10)
                        .cornerRadius(3)

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
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
        }
        .onAppear {
            selectedTemperature = loadCurrentTemperature(state: widget.item?.state) ?? 2700
        }
        .onChange(of: widget.item?.state ?? "") { newState in
            selectedTemperature = loadCurrentTemperature(state: newState) ?? 2700
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
        viewModel.sendCommand(widget.item, commandToSend: command)
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[13]
    VStack {
        ColorTemperaturePickerRowView(widget: widget)
            .padding()
        Spacer()
    }
}
