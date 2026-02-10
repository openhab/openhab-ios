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

struct SetpointRow: View {
    let widget: OpenHABWidget
    let stateToken: String
    @EnvironmentObject var settings: AppSettings
    private let setpointService = SetPointService()
    private let logger = Logger(subsystem: "org.openhab.watch", category: "SetpointRow")
    @State private var viewModel: WidgetRowViewModel
    @State private var localValue: Double?
    @State private var commandSender = WidgetCommandSender()

    private var currentValue: Double {
        localValue ?? viewModel.numberState?.value ?? viewModel.minValue
    }

    private var valueText: String {
        let value = currentValue.valueText(step: viewModel.step)
        if let unit = widget.unit, !unit.isEmpty {
            return "\(value) \(unit)"
        }
        return value
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                WatchIconView(model: widget.iconRenderModel(), settings: settings)
                Text(viewModel.labelText)
                    .watchTextStyle(.label)
                Spacer()
            }
            HStack {
                Spacer()

                Button(action: decreaseValue) {
                    Image(systemSymbol: .chevronDownCircleFill)
                        .font(.system(size: 25))
                        .foregroundStyle(currentValue <= viewModel.minValue ? Color.gray : Color.blue)
                }
                .buttonStyle(.plain)
                .disabled(currentValue <= viewModel.minValue)
                .accessibilityLabel("Decrease \(viewModel.labelText)")
                .accessibilityHint("Lowers by \(viewModel.step.valueText(step: viewModel.step))")

                Spacer()

                Text(localValue == nil ? (viewModel.labelValue ?? valueText) : valueText)
                    .watchTextStyle(.emphasis)
                    .accessibilityLabel("\(viewModel.labelText) value")
                    .accessibilityValue(localValue == nil ? (viewModel.labelValue ?? valueText) : valueText)

                Spacer()

                Button(action: increaseValue) {
                    Image(systemSymbol: .chevronUpCircleFill)
                        .font(.system(size: 25))
                        .foregroundStyle(currentValue >= viewModel.maxValue ? Color.gray : Color.blue)
                }
                .buttonStyle(.plain)
                .disabled(currentValue >= viewModel.maxValue)
                .accessibilityLabel("Increase \(viewModel.labelText)")
                .accessibilityHint("Raises by \(viewModel.step.valueText(step: viewModel.step))")

                Spacer()
            }
        }
        .onChange(of: stateToken, initial: false) { _, _ in
            viewModel.update(from: widget)
            localValue = nil
        }
    }

    init(widget: OpenHABWidget, stateToken: String) {
        self.widget = widget
        self.stateToken = stateToken
        _viewModel = State(wrappedValue: WidgetRowViewModel(widget: widget))
    }

    private func handleUpDown(isDecreasing: Bool) {
        let limitedNewValue = setpointService.calculateNewValue(
            currentValue: currentValue,
            step: viewModel.step,
            minValue: viewModel.minValue,
            maxValue: viewModel.maxValue,
            isDecreasing: isDecreasing
        )

        guard limitedNewValue != currentValue else {
            // nothing to update, skip sending value
            return
        }

        localValue = limitedNewValue
        let numberState = NumberState(value: limitedNewValue, unit: widget.unit)

        logger.info("Setpoint \(isDecreasing ? "decreased" : "increased") to \(numberState.description)")
        commandSender.sendItemUpdate(numberState, for: widget)
    }

    func decreaseValue() {
        handleUpDown(isDecreasing: true)
    }

    func increaseValue() {
        handleUpDown(isDecreasing: false)
    }
}

#Preview {
    let widget = PreviewWidgetFactory.setpoint(
        label: "Temperature",
        value: 21,
        minValue: 16,
        maxValue: 28,
        step: 0.5,
        unit: "°C"
    )
    PreviewNavigationContainer {
        SetpointRow(widget: widget, stateToken: widget.item?.state ?? widget.state)
    }
}
