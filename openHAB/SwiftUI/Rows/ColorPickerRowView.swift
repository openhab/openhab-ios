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
import SwiftUI

struct ColorPickerRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @State private var selectedColor: Color = .white

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetColorPickerView")

    var body: some View {
        HStack {
            if IconView.shouldShowIcon(for: widget) {
                IconView(widget: widget)
                    .frame(width: 24, height: 24)
            }

            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
            }

            Spacer()

            ColorPicker("Color", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: selectedColor) { newColor in
                    sendColorCommand(newColor)
                }

            if let labelValue = widget.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .font(.caption)
                    .foregroundColor(widget.valuecolor.isEmpty ? .secondary : Color(fromString: widget.valuecolor))
            }
        }
        .onAppear {
            if let state = widget.item?.state, !state.isEmpty {
                selectedColor = parseColor(from: state) ?? .white
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
        widget.sendCommand(command)
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
}
