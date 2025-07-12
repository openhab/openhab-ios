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

struct SliderWithSwitchRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @State private var sliderValue: Double = 0

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetSliderWithSwitchView")

    private var step: Double {
        widget.step
    }

    private var effectiveState: String {
        var state = widget.state
        if state.isEmpty {
            state = widget.item?.state ?? ""
        }
        return state
    }

    private var isSwitchOn: Bool {
        effectiveState.parseAsBool()
    }

    private var adjustedValue: Double {
        if let item = widget.item {
            adj(item.stateAsDouble())
        } else {
            widget.minValue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(widget.labelText ?? widget.label)
                        .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))

                    if let labelValue = widget.labelValue, !labelValue.isEmpty {
                        Text(labelValue)
                            .font(.caption)
                            .foregroundColor(widget.valuecolor.isEmpty ? .secondary : Color(fromString: widget.valuecolor))
                    } else {
                        Text(sliderValue.valueText(step: step))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { isSwitchOn },
                    set: { newValue in
                        let command = newValue ? "ON" : "OFF"
                        logger.info("Switch to \(command)")
                        widget.sendCommand(command)
                    }
                ))
                .labelsHidden()
            }

            Slider(
                value: $sliderValue,
                in: widget.minValue ... widget.maxValue,
                step: step
            ) { editing in
                if !editing {
                    logger.info("Slider new value = \(sliderValue)")
                    widget.sendCommand(sliderValue.valueText(step: step))
                }
            }
        }
        .onAppear {
            sliderValue = adjustedValue
        }
        .onChange(of: widget.item?.state) { _ in
            sliderValue = adjustedValue
        }
    }

    private func adj(_ raw: Double) -> Double {
        var valueAdjustedToStep = Double(floor(Float((raw - widget.minValue) / step)) * Float(step))
        valueAdjustedToStep += widget.minValue
        return valueAdjustedToStep.clamped(to: widget.minValue ... widget.maxValue)
    }
}
