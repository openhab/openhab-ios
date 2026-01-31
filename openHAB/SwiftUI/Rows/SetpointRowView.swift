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

struct SetpointRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel
    @State private var triggerFeedback = false

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
        HStack {
            IconView(widget: widget)
                .frame(width: 32, height: 32)

            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    triggerFeedback.toggle()
                    decreaseValue()
                } label: {
                    Image(systemSymbol: .chevronDown)
                        .font(.body)
                        .foregroundStyle(currentValue <= widget.minValue ? Color(.systemGray2) : Color(UIColor.systemBlue))
                }
                .buttonStyle(.plain)
                .disabled(currentValue <= widget.minValue)
                .sensoryHeavyFeedbackIfAvailable(trigger: triggerFeedback)
                .disabled(widget.readOnly ?? false)

                Text(formattedValue)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(widget.valuecolor.isEmpty ? .secondary : Color(fromString: widget.valuecolor))

                Button {
                    triggerFeedback.toggle()
                    increaseValue()
                } label: {
                    Image(systemSymbol: .chevronUp)
                        .font(.body)
                        .foregroundStyle(currentValue >= widget.maxValue ? Color(.systemGray2) : Color(UIColor.systemBlue))
                }
                .buttonStyle(.plain)
                .disabled(currentValue >= widget.maxValue)
                .sensoryHeavyFeedbackIfAvailable(trigger: triggerFeedback)
                .disabled(widget.readOnly ?? false)
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

        numberState = numberState ?? NumberState(value: limitedNewValue)
        numberState?.value = limitedNewValue

        logger.info("Setpoint \(isDecreasing ? "decreased" : "increased") to \(limitedNewValue)")
        viewModel.sendToUpdate(item: widget.item, state: numberState)
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[3]
    VStack {
        SetpointRowView(widget: widget)
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
