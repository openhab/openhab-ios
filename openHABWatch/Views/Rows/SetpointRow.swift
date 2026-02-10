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
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var settings: AppSettings
    private let setpointService = SetPointService()
    private let logger = Logger(subsystem: "org.openhab.watch", category: "SetpointRow")
    @State private var viewModel: WidgetRowViewModel
    @State private var commandSender = WidgetCommandSender()

    private var currentValue: Double {
        viewModel.numberState?.value ?? viewModel.minValue
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                IconView(widget: widget, settings: settings)
                WatchLabelText(widget: widget)
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

                Spacer()

                DetailTextLabelView(widget: widget)
                    .font(WatchTypography.emphasisFont)

                Spacer()

                Button(action: increaseValue) {
                    Image(systemSymbol: .chevronUpCircleFill)
                        .font(.system(size: 25))
                        .foregroundStyle(currentValue >= viewModel.maxValue ? Color.gray : Color.blue)
                }
                .buttonStyle(.plain)
                .disabled(currentValue >= viewModel.maxValue)

                Spacer()
            }
        }
        .onAppear {
            viewModel.update(from: widget)
        }
        .onChange(of: widget.item?.state, initial: false) { _, _ in
            viewModel.update(from: widget)
        }
    }

    private func handleUpDown(isDecreasing: Bool) {
        var numberState = viewModel.numberState
        let currentValue = numberState?.value ?? viewModel.minValue

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

        numberState = numberState ?? NumberState(value: limitedNewValue, unit: widget.unit)
        numberState?.value = limitedNewValue

        logger.info("Setpoint \(isDecreasing ? "decreased" : "increased") to \(numberState?.description ?? String(limitedNewValue))")
        commandSender.sendItemUpdate(numberState, for: widget)
    }

    func decreaseValue() {
        handleUpDown(isDecreasing: true)
    }

    func increaseValue() {
        handleUpDown(isDecreasing: false)
    }

    init(widget: OpenHABWidget) {
        self.widget = widget
        _viewModel = State(wrappedValue: WidgetRowViewModel(widget: widget))
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
        SetpointRow(widget: widget)
    }
}
