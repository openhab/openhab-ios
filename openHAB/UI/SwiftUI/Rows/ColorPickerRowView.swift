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
            .ohMinimumHitTarget()
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

    @State private var selectedColor: Color = .white
    @State private var lastImmediateSendAt: Date = .distantPast
    @State private var suppressNextColorSend = false

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

            Spacer()

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
            }

            ColorPicker("Color", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: selectedColor) { newColor in
                    sendColorCommand(newColor)
                }
                .disabled(input.readOnly)

            if !input.readOnly {
                BrightnessButton(
                    symbol: .arrowtriangleUpCircle,
                    accessibilityLabel: "Increase brightness",
                    tapCommand: "ON",
                    longPressCommand: "INCREASE",
                    onSend: onSendImmediate
                )
            }
        }
        .onAppear {
            applyServerState(displayState.effectiveState)
        }
        .onChange(of: displayState.effectiveState) { newState in
            applyServerState(newState)
        }
        .onDisappear {
            onCancelPending()
        }
    }

    private func sendColorCommand(_ color: Color) {
        if suppressNextColorSend {
            suppressNextColorSend = false
            return
        }

        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let hueValue = Int((hue * 360).rounded()).clamped(to: 0 ... 360)
        let saturationValue = Int((saturation * 100).rounded()).clamped(to: 0 ... 100)
        let brightnessValue = Int((brightness * 100).rounded()).clamped(to: 0 ... 100)

        let command = "\(hueValue),\(saturationValue),\(brightnessValue)"
        logger.info("Sending color command: \(command)")

        // Keep real-time feedback while dragging: throttle immediate sends.
        let now = Date()
        if now.timeIntervalSince(lastImmediateSendAt) >= 0.2 {
            lastImmediateSendAt = now
            onSendImmediate(command)
        }

        // Also debounce to ensure the final value is sent after interaction settles.
        onSendDebounced(command)
    }

    private func applyServerState(_ state: String) {
        guard !state.isEmpty, let parsedColor = parseColor(from: state) else { return }
        suppressNextColorSend = true
        selectedColor = parsedColor
    }

    private func parseColor(from state: String) -> Color? {
        let components = state.split(separator: ",")
        guard components.count >= 3,
              let hue = Double(components[0]),
              let saturation = Double(components[1]),
              let brightness = Double(components[2]) else {
            return nil
        }

        return Color(hue: hue / 360.0, saturation: saturation / 100.0, brightness: brightness / 100.0)
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
