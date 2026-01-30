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

    @State private var lastSendTime: Date = .distantPast
    @State private var debounceTask: Task<Void, Never>?

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetColorPickerView")

    var body: some View {
        HStack {
            IconView(widget: widget)
                .frame(width: 32, height: 32)

            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
            }

            Spacer()

            ColorPicker("Color", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: selectedColor) { newColor in
                    let now = Date()
                    if now.timeIntervalSince(lastSendTime) > 0.2 {
                        lastSendTime = now
                        sendColorCommand(newColor)
                    }
                    // ColorPicker does not provide an .onEnded like Slider as it doesn't expose the drag lifecycle.
                    // It only emits onChange when the color value changes.
                    // Therefore, we debounce final send after 0.3s of no changes
                    debounceTask?.cancel()
                    debounceTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                        sendColorCommand(newColor)
                    }
                }
                .disabled(widget.readOnly ?? false)

            if let labelValue = widget.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .font(.caption)
                    .foregroundStyle(widget.valuecolor.isEmpty ? .secondary : Color(fromString: widget.valuecolor))
            }
        }
        .onAppear {
            if let state = widget.item?.state, !state.isEmpty {
                selectedColor = parseColor(from: state) ?? .white
            }
        }
        .onChange(of: widget.item?.state ?? "") { newState in
            guard !newState.isEmpty else { return }
            selectedColor = parseColor(from: newState) ?? .white
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
        viewModel.sendCommand(widget.item, commandToSend: command)
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
