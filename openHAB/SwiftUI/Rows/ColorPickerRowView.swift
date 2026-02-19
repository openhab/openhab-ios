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
import SwiftUI

private struct ColorPickerRowConfig {
    let input: ColorPickerRowInput
    let iconWidget: OpenHABWidget
    let commandWidget: OpenHABWidget
    let viewModel: SitemapPageViewModel
}

@MainActor
private func makeColorPickerRowContent(_ config: ColorPickerRowConfig) -> ColorPickerRowContent {
    ColorPickerRowContent(
        input: config.input,
        iconWidget: config.iconWidget,
        onSendImmediate: { command in
            config.viewModel.sendCommand(command, for: config.commandWidget, policy: .immediate)
        },
        onSendDebounced: { command in
            config.viewModel.sendCommand(
                command,
                for: config.commandWidget,
                policy: WidgetCommandDefaults.colorPicker,
                key: config.input.colorCommandKey
            )
        },
        onCancelPending: {
            if let item = config.commandWidget.item {
                config.viewModel.cancelPendingCommand(for: item, key: config.input.colorCommandKey)
            } else {
                config.viewModel.cancelPendingCommand(for: config.commandWidget, key: config.input.colorCommandKey)
            }
        }
    )
}

private struct ColorPickerRowContent: View {
    let input: ColorPickerRowInput
    let iconWidget: OpenHABWidget
    let onSendImmediate: (String) -> Void
    let onSendDebounced: (String) -> Void
    let onCancelPending: () -> Void

    @State private var selectedColor: Color = .white
    @State private var lastImmediateSendAt: Date = .distantPast

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetColorPickerView")

    var body: some View {
        let displayState = input.displayState
        HStack {
            IconView(widget: iconWidget)
                .frame(width: 32, height: 32)

            if !displayState.labelText.isEmpty {
                let labelText = displayState.labelText
                Text(labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))
            }

            Spacer()

            ColorPicker("Color", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: selectedColor) { newColor in
                    sendColorCommand(newColor)
                }
                .disabled(input.readOnly)

            if let labelValue = displayState.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .ohTextToken(.rowValueCompact)
                    .foregroundStyle(input.valueColor.isEmpty ? .secondary : Color(fromString: input.valueColor))
            }
        }
        .onAppear {
            let state = displayState.effectiveState
            if !state.isEmpty {
                selectedColor = parseColor(from: state) ?? .white
            }
        }
        .onChange(of: displayState.effectiveState) { newState in
            guard !newState.isEmpty else { return }
            selectedColor = parseColor(from: newState) ?? .white
        }
        .onDisappear {
            onCancelPending()
        }
    }

    private func sendColorCommand(_ color: Color) {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let hueValue = Int(hue * 360)
        let saturationValue = Int(saturation * 100)
        let brightnessValue = Int(brightness * 100)

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

struct ColorPickerRowInputView: View {
    let rowID: RowID
    let input: ColorPickerRowInput
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        if let widget = viewModel.widget(for: rowID) {
            makeColorPickerRowContent(
                ColorPickerRowConfig(
                    input: input,
                    iconWidget: widget,
                    commandWidget: widget,
                    viewModel: viewModel
                )
            )
        } else {
            EmptyView()
        }
    }
}

struct ColorPickerRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        makeColorPickerRowContent(
            ColorPickerRowConfig(
                input: ColorPickerRowInput.from(widget: widget),
                iconWidget: widget,
                commandWidget: widget,
                viewModel: viewModel
            )
        )
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[15]
    VStack {
        ColorPickerRowView(widget: widget)
            .padding()
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
