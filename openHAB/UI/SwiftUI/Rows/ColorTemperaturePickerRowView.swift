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

enum ColorTemperatureRowMath {
    static let minimumKelvin = 1000.0
    static let maximumKelvin = 10000.0
    static let warmWhiteKelvin = 2700.0
    static let minimumGradientSteps = 1
    static let minimumSliderStep = 1.0
    static let minimumValidSpan = 0.0
    static let minimumConvertibleKelvin = 0.0
    static let fractionLowerBound = 0.0
    static let fractionUpperBound = 1.0

    static let fallbackRange: ClosedRange<Double> = minimumKelvin ... maximumKelvin
    static let fallbackTemperature = warmWhiteKelvin

    static func normalizedRange(minValue: Double, maxValue: Double) -> ClosedRange<Double> {
        let lowerCandidate = sanitizeTemperatureValue(minValue) ?? fallbackRange.lowerBound
        let upperCandidate = sanitizeTemperatureValue(maxValue) ?? fallbackRange.upperBound

        let lower = min(lowerCandidate, upperCandidate).clamped(to: fallbackRange)
        let upper = max(lowerCandidate, upperCandidate).clamped(to: fallbackRange)

        guard lower.isFinite, upper.isFinite, lower < upper else {
            return fallbackRange
        }

        return lower ... upper
    }

    static func normalizedTemperature(state: String?, serverValue: Double?, range: ClosedRange<Double>) -> Double {
        let resolvedValue = state.flatMap { parseTemperature(state: $0) }
            ?? sanitizeTemperatureValue(serverValue)
            ?? fallbackTemperature
        return resolvedValue.clamped(to: range)
    }

    static func gradientTemperatures(for range: ClosedRange<Double>, steps: Int) -> [Double] {
        let safeSteps = max(steps, minimumGradientSteps)
        let span = range.upperBound - range.lowerBound
        return (0 ... safeSteps).map { index in
            range.lowerBound + (span * Double(index) / Double(safeSteps))
        }
    }

    static func sliderFraction(value: Double, range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span.isFinite, span > minimumValidSpan else { return fractionLowerBound }

        let fraction = (value - range.lowerBound) / span
        return fraction.clamped(to: fractionLowerBound ... fractionUpperBound)
    }

    static func sanitizeTemperatureValue(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value > minimumConvertibleKelvin else { return nil }
        let convertedValue = value < fallbackRange.lowerBound ? value.asColorTemperatureInKelvin : value
        return convertedValue.isFinite ? convertedValue : nil
    }

    private static func parseTemperature(state: String) -> Double? {
        guard !state.isEmpty else { return nil }
        return sanitizeTemperatureValue(state.parseAsNumber().value)
    }
}

private struct ColorTemperatureRowConfig {
    let input: ColorTemperatureRowInput
    let viewModel: SitemapPageViewModel
}

@MainActor
private func makeColorTemperatureRowContent(_ config: ColorTemperatureRowConfig) -> ColorTemperaturePickerRowContent {
    ColorTemperaturePickerRowContent(
        input: config.input,
        iconInput: config.input.icon
    ) { command, key in
        guard let itemName = config.input.itemName else { return }
        config.viewModel.sendCommand(
            command,
            for: itemName,
            policy: WidgetCommandDefaults.slider,
            key: key
        )
    } onCancelPending: { key in
        guard let itemName = config.input.itemName else { return }
        config.viewModel.cancelPendingCommand(for: itemName, key: key)
    }
}

struct CustomSliderView: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let onEditingChanged: () -> Void
    let onDragStateChanged: (Bool) -> Void

    @State private var lastSendTime: Date = .distantPast
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let normalized = CGFloat(ColorTemperatureRowMath.sliderFraction(value: value, range: range))
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
                                if !isDragging {
                                    isDragging = true
                                    onDragStateChanged(true)
                                }
                                guard width > ColorTemperatureRowMath.minimumValidSpan else { return }
                                let location = gesture.location.x.clamped(to: 0 ... width)
                                let raw = Double(location / width) * (range.upperBound - range.lowerBound) + range.lowerBound
                                let safeStep = max(step, ColorTemperatureRowMath.minimumSliderStep)
                                let stepped = (raw / safeStep).rounded() * safeStep
                                value = stepped.clamped(to: range)
                                let now = Date()
                                if now.timeIntervalSince(lastSendTime) > 0.2 {
                                    lastSendTime = now
                                    onEditingChanged()
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                                onDragStateChanged(false)
                                onEditingChanged()
                            }
                    )
            }
        }
    }
}

private struct ColorTemperaturePickerRowContent: View {
    let input: ColorTemperatureRowInput
    let iconInput: RowIconInput
    let onSendCommand: (String, String) -> Void
    let onCancelPending: (String) -> Void

    @State private var selectedTemperature: Double = 2700 // Default warm white
    @State private var isDraggingSlider = false
    @State private var suppressNextServerSync = false

    private let logger = Logger(subsystem: "org.openhab", category: "ColorTemperaturePickerRowView")

    private var temperatureRange: ClosedRange<Double> {
        ColorTemperatureRowMath.normalizedRange(minValue: input.minValue, maxValue: input.maxValue)
    }

    var body: some View {
        let displayState = input.displayState
        RowViewWithIcon(input: input, alignment: .top) {
            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    if !displayState.labelText.isEmpty {
                        Text(displayState.labelText)
                            .ohTextToken(.rowLabel)
                            .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))
                    }

                    Spacer(minLength: 0)

                    // Temperature value display
                    HStack(spacing: 0) {
                        Text("\(Int(selectedTemperature))K")
                            .ohTextToken(.rowValueCompact)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()

                        Text(" - ")
                            .ohTextToken(.rowValueCompact)
                            .foregroundStyle(.secondary)

                        Text(temperatureDescription)
                            .ohTextToken(.secondary)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 6)

                // Color temperature slider with gradient background
                HStack {
                    // Warm indicator
                    Image(systemSymbol: .sunMinFill)
                        .foregroundStyle(.orange)
                        .ohTextToken(.secondary)

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
                            range: temperatureRange,
                            step: 100,
                            onEditingChanged: {
                                sendTemperatureCommand()
                            },
                            onDragStateChanged: { isDragging in
                                isDraggingSlider = isDragging
                            }
                        )
                        .frame(height: 28)
                        .disabled(input.readOnly)
                    }

                    // Cool indicator
                    Image(systemSymbol: .snowflake)
                        .foregroundStyle(.blue)
                        .ohTextToken(.secondary)
                }
            }
        }
        .onAppear {
            selectedTemperature = loadCurrentTemperature(state: displayState.effectiveState)
        }
        .onChange(of: displayState.effectiveState) { newState in
            guard !isDraggingSlider else { return }
            if suppressNextServerSync {
                suppressNextServerSync = false
                return
            }
            selectedTemperature = loadCurrentTemperature(state: newState)
        }
        .onDisappear {
            onCancelPending(input.colorTemperatureCommandKey)
        }
    }

    private var temperatureDescription: String {
        switch selectedTemperature {
        case 1000 ..< 2000: String(localized: "Candlelight")
        case 2000 ..< 2700: String(localized: "Very Warm")
        case 2700 ..< 3000: String(localized: "Warm White")
        case 3000 ..< 4000: String(localized: "Soft White")
        case 4000 ..< 5000: String(localized: "Cool White")
        case 5000 ..< 6500: String(localized: "Daylight")
        case 6500 ..< 8000: String(localized: "Cool Daylight")
        default: String(localized: "Very Cool")
        }
    }

    /// Generate gradient colors similar to Android implementation
    private func colorTemperatureGradient(steps: Int = 20) -> [Color] {
        ColorTemperatureRowMath.gradientTemperatures(for: temperatureRange, steps: steps).map { Color(temperature: $0) }
    }

    private func loadCurrentTemperature(state: String?) -> Double {
        ColorTemperatureRowMath.normalizedTemperature(
            state: state,
            serverValue: input.serverValue,
            range: temperatureRange
        )
    }

    private func sendTemperatureCommand() {
        // Send temperature directly as Kelvin value (like Android app)
        let clampedRoundedTemperature = Int(selectedTemperature.rounded()).clamped(
            to: Int(temperatureRange.lowerBound) ... Int(temperatureRange.upperBound)
        )
        let command = "\(clampedRoundedTemperature)"

        logger.info("Sending color temperature command: \(command)K")
        suppressNextServerSync = true
        onSendCommand(command, input.colorTemperatureCommandKey)
    }
}

struct ColorTemperaturePickerRowView: View {
    let input: ColorTemperatureRowInput
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        makeColorTemperatureRowContent(
            ColorTemperatureRowConfig(
                input: input,
                viewModel: viewModel
            )
        )
    }
}

#if DEBUG
#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[13]
    VStack {
        ColorTemperaturePickerRowView(input: ColorTemperatureRowInput.from(widget: widget))
            .padding()
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
#endif
