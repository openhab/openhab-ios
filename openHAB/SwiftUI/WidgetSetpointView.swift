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
import SFSafeSymbols
import SwiftUI

struct WidgetSetpointView: View {
    @ObservedObject var widget: OpenHABWidget

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetSetpointView")
    private let setpointService = SetPointService()

    private var currentValue: Double {
        widget.stateValueAsNumberState?.value ?? widget.minValue
    }

    private var formattedValue: String {
        if let labelValue = widget.labelValue, !labelValue.isEmpty {
            return labelValue
        } else {
            let step = widget.step
            if step.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", currentValue)
            } else {
                return String(format: "%.1f", currentValue)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if WidgetIconView.shouldShowIcon(for: widget) {
                    WidgetIconView(widget: widget)
                        .frame(width: 24, height: 24)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(widget.labelText ?? widget.label)
                        .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(UIColor(fromString: widget.labelcolor)))
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(action: decreaseValue) {
                        Image(systemSymbol: .chevronDownCircleFill)
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentValue <= widget.minValue)

                    Text(formattedValue)
                        .font(.caption)
                        .foregroundColor(widget.valuecolor.isEmpty ? .secondary : Color(UIColor(fromString: widget.valuecolor)))

                    Button(action: increaseValue) {
                        Image(systemSymbol: .chevronUpCircleFill)
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentValue >= widget.maxValue)
                }
            }
        }
    }

    private func decreaseValue() {
        handleUpDown(isDecreasing: true)
    }

    private func increaseValue() {
        handleUpDown(isDecreasing: false)
    }

    private func handleUpDown(isDecreasing: Bool) {
        var numberState = widget.stateValueAsNumberState
        let currentValue = numberState?.value ?? widget.minValue

        let limitedNewValue = setpointService.calculateNewValue(
            currentValue: currentValue,
            step: widget.step,
            minValue: widget.minValue,
            maxValue: widget.maxValue,
            isDecreasing: isDecreasing
        )

        guard limitedNewValue != currentValue else {
            // nothing to update, skip sending value
            return
        }

        if numberState != nil {
            numberState?.value = limitedNewValue
        } else {
            numberState = NumberState(value: limitedNewValue)
        }

        logger.info("Setpoint \(isDecreasing ? "decreased" : "increased") to \(limitedNewValue)")
        widget.sendItemUpdate(state: numberState)
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[3]
    WidgetSetpointView(widget: widget)
}
