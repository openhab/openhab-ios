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

private struct HSBSelection: Equatable {
    static let `default` = HSBSelection(hue: 0, saturation: 0, brightness: 1)

    var hue: Double
    var saturation: Double
    var brightness: Double

    var color: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    var wheelColor: Color {
        Color(hue: hue, saturation: saturation, brightness: 1)
    }

    var brightnessGradientColors: [Color] {
        [
            Color(hue: hue, saturation: saturation, brightness: 0),
            Color(hue: hue, saturation: saturation, brightness: 1)
        ]
    }

    var openHABCommand: String {
        let hueValue = Int((hue * 360).rounded()).clamped(to: 0 ... 360)
        let saturationValue = Int((saturation * 100).rounded()).clamped(to: 0 ... 100)
        let brightnessValue = Int((brightness * 100).rounded()).clamped(to: 0 ... 100)
        return "\(hueValue),\(saturationValue),\(brightnessValue)"
    }
}

private struct ColorWheelView: View {
    @Binding var selection: HSBSelection
    let isEnabled: Bool
    let onEditingChanged: (Bool) -> Void

    private let indicatorSize = 28.0
    private let dotDiameter = 12.0
    private let ringCount = 10
    private let ringSpread = 0.94
    private let hueRotation = 0.25

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                Canvas { context, _ in
                    drawWheel(in: context, size: size)
                }

                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 3)
                    .frame(width: indicatorSize, height: indicatorSize)
                    .background(
                        Circle()
                            .fill(selection.wheelColor)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 1)
                    .position(indicatorPosition(for: size))
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard isEnabled else { return }
                        onEditingChanged(true)
                        updateSelection(for: gesture.location, size: size)
                    }
                    .onEnded { gesture in
                        guard isEnabled else { return }
                        updateSelection(for: gesture.location, size: size)
                        onEditingChanged(false)
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("Color wheel")
            .accessibilityValue(accessibilityValue)
            .accessibilityHint("Drag to change hue and saturation")
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var accessibilityValue: String {
        let huePercent = Int((selection.hue * 100).rounded())
        let saturationPercent = Int((selection.saturation * 100).rounded())
        return "Hue \(huePercent) percent, saturation \(saturationPercent) percent"
    }

    private func drawWheel(in context: GraphicsContext, size: CGFloat) {
        let radius = size / 2
        let center = CGPoint(x: radius, y: radius)
        let dotRadius = CGFloat(dotDiameter / 2)
        let availableRadius = max(0, radius - dotRadius)

        drawDot(
            at: center,
            color: Color(hue: 0, saturation: 0, brightness: 1),
            dotRadius: dotRadius,
            in: context
        )

        guard ringCount > 0, availableRadius > 0 else { return }

        for ringIndex in 1 ... ringCount {
            let ringFraction = CGFloat(ringIndex) / CGFloat(ringCount)
            let ringRadius = ringFraction * availableRadius * ringSpread
            let dotCount = ringIndex * 6

            for dotIndex in 0 ..< dotCount {
                let angle = (Double(dotIndex) / Double(dotCount)) * 2 * Double.pi
                let point = CGPoint(
                    x: center.x + CGFloat(sin(angle)) * ringRadius,
                    y: center.y + CGFloat(cos(angle)) * ringRadius
                )
                let hue = wrappedHue(hueRotation - angle / (2 * Double.pi))
                let saturation = (ringRadius / availableRadius).clamped(to: 0 ... 1)
                let color = Color(hue: hue, saturation: saturation, brightness: 1)
                drawDot(at: point, color: color, dotRadius: dotRadius, in: context)
            }
        }
    }

    private func drawDot(at point: CGPoint, color: Color, dotRadius: CGFloat, in context: GraphicsContext) {
        let rect = CGRect(
            x: point.x - dotRadius,
            y: point.y - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
        )
        context.fill(Circle().path(in: rect), with: .color(color))
    }

    private func indicatorPosition(for size: CGFloat) -> CGPoint {
        let radius = Double(size) / 2
        let angle = (hueRotation - selection.hue) * 2 * Double.pi
        let distance = selection.saturation * radius
        return CGPoint(
            x: CGFloat(radius + sin(angle) * distance),
            y: CGFloat(radius + cos(angle) * distance)
        )
    }

    private func updateSelection(for location: CGPoint, size: CGFloat) {
        let center = CGPoint(x: size / 2, y: size / 2)
        let dx = Double(location.x - center.x)
        let dy = Double(location.y - center.y)
        let radius = min(sqrt(dx * dx + dy * dy), Double(size / 2))
        let normalizedAngle = atan2(dx, dy)
        let angle = normalizedAngle >= 0 ? normalizedAngle : (2 * Double.pi + normalizedAngle)

        selection.hue = wrappedHue(hueRotation - angle / (2 * Double.pi))
        selection.saturation = (radius / max(Double(size / 2), 1)).clamped(to: 0 ... 1)
    }

    private func wrappedHue(_ value: Double) -> Double {
        let wrapped = value.truncatingRemainder(dividingBy: 1)
        return wrapped >= 0 ? wrapped : wrapped + 1
    }
}

private struct BrightnessSliderView: View {
    @Binding var selection: HSBSelection
    let isEnabled: Bool
    let onEditingChanged: (Bool) -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text(verbatim: selection.brightness.formatted(.percent.precision(.fractionLength(0))))
                .ohTextToken(.secondary)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            ZStack {
                LinearGradient(
                    colors: selection.brightnessGradientColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 10)
                .clipShape(.rect(cornerRadius: 3))

                Slider(
                    value: $selection.brightness,
                    in: 0 ... 1,
                    onEditingChanged: onEditingChanged
                )
                .tint(.clear)
                .disabled(!isEnabled)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct ColorWheelSheetView: View {
    @Binding var selection: HSBSelection
    let isEnabled: Bool
    let onWheelEditingChanged: (Bool) -> Void
    let onSliderEditingChanged: (Bool) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ColorWheelView(
                    selection: $selection,
                    isEnabled: isEnabled,
                    onEditingChanged: onWheelEditingChanged
                )
                .frame(maxWidth: .infinity, alignment: .center)

                BrightnessSliderView(
                    selection: $selection,
                    isEnabled: isEnabled,
                    onEditingChanged: onSliderEditingChanged
                )

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .navigationTitle("Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .presentationDetents([.fraction(0.72)])
    }
}

private struct ColorPickerRowConfig {
    let input: ColorPickerRowInput
    let viewModel: SitemapPageViewModel
}

@MainActor
private func makeColorPickerRowContent(_ config: ColorPickerRowConfig) -> ColorPickerRowContent {
    ColorPickerRowContent(
        input: config.input,
        onSendImmediate: { command in
            guard let itemName = config.input.itemName else { return }
            config.viewModel.sendCommand(command, for: itemName, policy: .immediate)
        },
        onSendDebounced: { command in
            guard let itemName = config.input.itemName else { return }
            config.viewModel.sendCommand(
                command,
                for: itemName,
                policy: WidgetCommandDefaults.colorPicker,
                key: config.input.colorCommandKey
            )
        },
        onCancelPending: {
            guard let itemName = config.input.itemName else { return }
            config.viewModel.cancelPendingCommand(for: itemName, key: config.input.colorCommandKey)
        }
    )
}

/// A button that sends `tapCommand` on a short press and `longPressCommand` after a 0.5 s hold,
/// matching the openHAB BasicUI colorpicker behaviour (ON/OFF for tap, INCREASE/DECREASE for hold).
private struct BrightnessButton: View {
    let symbol: SFSymbol
    let accessibilityLabel: String
    let tapCommand: String
    let longPressCommand: String
    let onSend: (String) -> Void

    @State private var longPressTask: Task<Void, Never>?
    @State private var isLongPress = false
    @State private var triggerFeedback = false

    var body: some View {
        Image(systemSymbol: symbol)
            .font(.title2)
            .foregroundStyle(Color(UIColor.systemBlue))
            .contentShape(Rectangle())
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onSend(tapCommand) }
            .sensoryHeavyFeedbackIfAvailable(trigger: triggerFeedback)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressStarted() }
                    .onEnded { _ in pressEnded() }
            )
            .onDisappear {
                longPressTask?.cancel()
                longPressTask = nil
            }
    }

    private func pressStarted() {
        guard longPressTask == nil else { return }
        isLongPress = false
        longPressTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            isLongPress = true
            triggerFeedback.toggle()
            onSend(longPressCommand)
        }
    }

    private func pressEnded() {
        longPressTask?.cancel()
        longPressTask = nil
        guard !isLongPress else {
            isLongPress = false
            return
        }
        triggerFeedback.toggle()
        onSend(tapCommand)
    }
}

private struct ColorPickerRowContent: View {
    let input: ColorPickerRowInput
    let onSendImmediate: (String) -> Void
    let onSendDebounced: (String) -> Void
    let onCancelPending: () -> Void

    @State private var selection = HSBSelection.default
    @State private var lastImmediateSendAt: Date = .distantPast
    @State private var isEditingColor = false
    @State private var isPresentingColorWheel = false
    @State private var suppressNextColorSync = false
    @State private var triggerFeedback = false

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetColorPickerView")

    var body: some View {
        let displayState = input.displayState
        RowViewWithIcon(input: input) {
            if !displayState.labelText.isEmpty {
                let labelText = displayState.labelText
                Text(labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))
            }

            Spacer(minLength: 0)

            if let labelValue = displayState.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .ohTextToken(.rowValueCompact)
                    .foregroundStyle(input.valueColor.isEmpty ? .secondary : Color(fromString: input.valueColor))
            }

            if !input.readOnly {
                BrightnessButton(
                    symbol: .arrowtriangleDownCircle,
                    accessibilityLabel: "Decrease brightness",
                    tapCommand: "OFF",
                    longPressCommand: "DECREASE",
                    onSend: onSendImmediate
                )

                Button {
                    triggerFeedback.toggle()
                    isPresentingColorWheel = true
                } label: {
                    Circle()
                        .fill(selection.color)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.85), lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                }
                .buttonStyle(.plain)
                .sensoryHeavyFeedbackIfAvailable(trigger: triggerFeedback)
                .accessibilityLabel("Choose color")
                .accessibilityValue(colorAccessibilityValue)

                BrightnessButton(
                    symbol: .arrowtriangleUpCircle,
                    accessibilityLabel: "Increase brightness",
                    tapCommand: "ON",
                    longPressCommand: "INCREASE",
                    onSend: onSendImmediate
                )
            } else {
                Circle()
                    .fill(selection.color)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.85), lineWidth: 2)
                    )
                    .accessibilityHidden(true)
            }
        }
        .onAppear {
            applyServerState(displayState.effectiveState)
        }
        .onChange(of: displayState.effectiveState) { _, newState in
            guard !isEditingColor, !isPresentingColorWheel else { return }
            applyServerState(newState)
        }
        .onChange(of: selection) {
            sendColorCommand()
        }
        .sheet(isPresented: $isPresentingColorWheel) {
            ColorWheelSheetView(
                selection: $selection,
                isEnabled: !input.readOnly,
                onWheelEditingChanged: handleWheelEditingChanged(_:),
                onSliderEditingChanged: handleSliderEditingChanged(_:),
                onDismiss: dismissColorWheel
            )
        }
        .onDisappear {
            onCancelPending()
        }
    }

    private var colorAccessibilityValue: String {
        let huePercent = Int((selection.hue * 100).rounded())
        let saturationPercent = Int((selection.saturation * 100).rounded())
        let brightnessPercent = Int((selection.brightness * 100).rounded())
        return "Hue \(huePercent) percent, saturation \(saturationPercent) percent, brightness \(brightnessPercent) percent"
    }

    private func sendColorCommand() {
        if suppressNextColorSync {
            suppressNextColorSync = false
            return
        }

        let command = selection.openHABCommand
        logger.info("Sending color command: \(command)")

        let now = Date()
        if now.timeIntervalSince(lastImmediateSendAt) >= 0.2 {
            lastImmediateSendAt = now
            onSendImmediate(command)
        }

        onSendDebounced(command)
    }

    private func applyServerState(_ state: String) {
        guard !state.isEmpty, let parsedSelection = parseSelection(from: state) else { return }
        suppressNextColorSync = true
        selection = parsedSelection
    }

    private func parseSelection(from state: String) -> HSBSelection? {
        let components = state.split(separator: ",")
        guard components.count >= 3,
              let hue = Double(components[0]),
              let saturation = Double(components[1]),
              let brightness = Double(components[2]) else {
            return nil
        }

        return HSBSelection(
            hue: (hue / 360.0).clamped(to: 0 ... 1),
            saturation: (saturation / 100.0).clamped(to: 0 ... 1),
            brightness: (brightness / 100.0).clamped(to: 0 ... 1)
        )
    }

    private func handleWheelEditingChanged(_ isEditing: Bool) {
        isEditingColor = isEditing
    }

    private func handleSliderEditingChanged(_ isEditing: Bool) {
        isEditingColor = isEditing
        if !isEditing {
            onSendImmediate(selection.openHABCommand)
        }
    }

    private func dismissColorWheel() {
        isEditingColor = false
        isPresentingColorWheel = false
        onSendImmediate(selection.openHABCommand)
    }
}

struct ColorPickerRowView: View {
    let input: ColorPickerRowInput
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        makeColorPickerRowContent(
            ColorPickerRowConfig(
                input: input,
                viewModel: viewModel
            )
        )
    }
}

#if DEBUG
#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[15]
    VStack {
        ColorPickerRowView(input: ColorPickerRowInput.from(widget: widget))
            .padding()
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
#endif
