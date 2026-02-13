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

struct ColorPickerRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @State private var selectedColor: Color = .white
    @EnvironmentObject var viewModel: SitemapPageViewModel

    private var colorCommandKey: String {
        "color-\(widget.widgetId)"
    }

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetColorPickerView")
    private var displayState: WidgetDisplayState { widget.displayState }

    var body: some View {
        HStack {
            IconView(widget: widget)
                .frame(width: 32, height: 32)

            if !displayState.labelText.isEmpty {
                let labelText = displayState.labelText
                Text(labelText)
                    .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
                    .lineLimit(1)
            }

            Spacer()

            ColorPicker("Color", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: selectedColor) { newColor in
                    sendColorCommand(newColor)
                }
                .disabled(widget.readOnly ?? false)

            if let labelValue = displayState.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .font(.caption)
                    .foregroundStyle(widget.valuecolor.isEmpty ? .secondary : Color(fromString: widget.valuecolor))
                    .lineLimit(1)
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
            if let item = widget.item {
                viewModel.cancelPendingCommand(for: item, key: colorCommandKey)
            } else {
                viewModel.cancelPendingCommand(for: widget, key: colorCommandKey)
            }
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
        viewModel.sendCommand(
            command,
            for: widget,
            policy: WidgetCommandDefaults.colorPicker,
            key: colorCommandKey
        )
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

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[15]
    VStack {
        ColorPickerRowView(widget: widget)
            .padding()
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
