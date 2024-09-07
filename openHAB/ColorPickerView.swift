// Copyright (c) 2010-2024 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Combine
import OpenHABCore
import SwiftUI

struct ColorPickerView: View {
    @State private var selectedColor: Color = .white
    @State private var hue: Double = 0.0
    @State private var saturation: Double = 0.0
    @State private var brightness: Double = 0.0

    @ObservedObject var throttler = Throttler(maxInterval: 0.3)

    var widget: OpenHABWidget? // OpenHAB widget for sending commands

    var body: some View {
        VStack {
            // SwiftUI Color Picker
            ColorPicker("Pick a Color", selection: $selectedColor)
                .onChange(of: selectedColor) { newColor in
                    throttler.throttle {
                        updateHSB(from: newColor)
                        sendColorUpdate()
                    }
                }
                .padding()

            // Displaying HSB values
            Text("Hue: \(hue, specifier: "%.2f")")
            Text("Saturation: \(saturation, specifier: "%.2f")")
            Text("Brightness: \(brightness, specifier: "%.2f")")
        }
        .onAppear {
            // Set initial color from widget if available
            if let initialColor = widget?.item?.stateAsUIColor() {
                selectedColor = Color(initialColor)
            }
        }
        .background(Color(UIColor.systemBackground))
    }

    // Update hue, saturation, brightness from Color
    func updateHSB(from color: Color) {
        let uiColor = UIColor(color)
        // swiftlint:disable:next large_tuple
        var (hue, saturation, brightness, alpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0.0, 0.0, 0.0, 0.0)
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        self.hue = Double(hue * 360) // Convert to degrees
        self.saturation = Double(saturation * 100)
        self.brightness = Double(brightness * 100)
    }

    // Send the color update to the widget
    func sendColorUpdate() {
        let command = "\(hue),\(saturation),\(brightness)"
        print("Sending command: \(command)")
        widget?.sendCommand(command)
    }
}

#Preview {
    ColorPickerView()
}
