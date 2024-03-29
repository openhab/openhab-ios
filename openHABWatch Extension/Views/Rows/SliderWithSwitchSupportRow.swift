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

import OpenHABCore
import os.log
import SwiftUI

struct SliderWithSwitchSupportRow: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    var body: some View {
        let valueBinding = Binding<Double>(
            get: {
                widget.adjustedValue
            },
            set: {
                os_log("Slider new value = %g", log: .default, type: .info, $0)
                widget.sendCommand($0.valueText(step: widget.step))

                // self.widget.stateEnumBinding = .slider($0)
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
                    os_log("Switch to ON", log: .viewCycle, type: .info)
                    widget.sendCommand(widget.maxValue.valueText(step: widget.step))
                } else {
                    os_log("Switch to OFF", log: .viewCycle, type: .info)
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

struct SliderWithSwitchSupportRow_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[3]
        return Group {
            SliderRow(widget: widget)
                .previewLayout(.fixed(width: 300, height: 70))
            SliderRow(widget: widget)
                .previewDevice("Apple Watch Series 4 - 44mm")
        }
    }
}
