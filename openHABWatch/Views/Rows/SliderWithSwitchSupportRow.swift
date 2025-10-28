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

import OpenHABCore
import os.log
import SwiftUI

struct SliderWithSwitchSupportRow: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var settings: AppSettings
    @State private var pendingValue: Double?

    var body: some View {
        let valueBinding = Binding<Double>(
            get: {
                pendingValue ?? widget.adjustedValue
            },
            set: { newValue in
                Logger.rowViews.info("SliderWithSwitchSupportRow new value = \(newValue)")
                pendingValue = newValue
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // 500ms delay
                    if pendingValue == newValue { // Ensure no new updates came in
                        widget.sendCommand(newValue.valueText(step: widget.step))
                        pendingValue = nil
                    }
                }
            }
        )

        let stateBinding = Binding<Bool>(
            get: {
                if widget.adjustedValue > widget.minValue {
                    true
                } else {
                    false
                }
            },
            set: {
                if $0 {
                    Logger.rowViews.info("Switch to ON")
                    widget.sendCommand(widget.maxValue.valueText(step: widget.step))
                } else {
                    Logger.rowViews.info("Switch to OFF")
                    widget.sendCommand(widget.minValue.valueText(step: widget.step))
                }
            }
        )

        return
            VStack(spacing: 3) {
                Toggle(isOn: stateBinding) {
                    HStack {
                        IconView(widget: widget, settings: settings)
                        VStack {
                            TextLabelView(widget: widget)
                            DetailTextLabelView(widget: widget)
                        }
                    }
                }
                .focusable(true)
                .padding(.trailing)
                .cornerRadius(5)

                Slider(value: valueBinding, in: widget.minValue ... widget.maxValue, step: widget.step)
                    .labelsHidden()
                    .focusable(true)
                    .digitalCrownRotation(
                        valueBinding,
                        from: widget.minValue,
                        through: widget.maxValue,
                        by: widget.step,
                        sensitivity: .medium,
                        isHapticFeedbackEnabled: true
                    )
            }
    }
}

#Preview {
    let widget = UserData(preview: true).widgets[3]
    return Group {
        SliderRow(widget: widget)
        SliderRow(widget: widget)
    }
    .environmentObject(AppSettings())
}
