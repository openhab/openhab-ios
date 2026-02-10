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
    let title: String
    let minValue: Double
    let maxValue: Double
    let step: Double
    let stateValue: Double?
    let labelValue: String?
    let unit: String?
    let stateToken: String
    @EnvironmentObject var settings: AppSettings
    private let setpointService = SetPointService()
    private let logger = Logger(subsystem: "org.openhab.watch", category: "SetpointRow")
    @State private var localValue: Double?
    @State private var commandSender = WidgetCommandSender()

    private var currentValue: Double {
        localValue ?? stateValue ?? minValue
    }

    private var valueText: String {
        let value = currentValue.valueText(step: step)
        if let unit, !unit.isEmpty {
            return "\(value) \(unit)"
        }
        return value
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                WatchIconView(model: widget.iconRenderModel(), settings: settings)
                Text(title)
                    .font(WatchTypography.labelFont)
                    .lineLimit(WatchTypography.labelLineLimit)
                    .minimumScaleFactor(WatchTypography.labelMinScale)
                    .truncationMode(.tail)
                Spacer()
            }
            HStack {
                Spacer()

                Button(action: decreaseValue) {
                    Image(systemSymbol: .chevronDownCircleFill)
                        .font(.system(size: 25))
                        .foregroundStyle(currentValue <= minValue ? Color.gray : Color.blue)
                }
                .buttonStyle(.plain)
                .disabled(currentValue <= minValue)

                Spacer()

                Text(localValue == nil ? (labelValue ?? valueText) : valueText)
                    .font(WatchTypography.emphasisFont)

                Spacer()

                Button(action: increaseValue) {
                    Image(systemSymbol: .chevronUpCircleFill)
                        .font(.system(size: 25))
                        .foregroundStyle(currentValue >= maxValue ? Color.gray : Color.blue)
                }
                .buttonStyle(.plain)
                .disabled(currentValue >= maxValue)

                Spacer()
            }
        }
        .onChange(of: stateToken, initial: false) { _, _ in
            localValue = nil
        }
    }

    init(widget: OpenHABWidget,
         title: String,
         minValue: Double,
         maxValue: Double,
         step: Double,
         stateValue: Double?,
         labelValue: String?,
         unit: String?,
         stateToken: String) {
        self.widget = widget
        self.title = title
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
        self.stateValue = stateValue
        self.labelValue = labelValue
        self.unit = unit
        self.stateToken = stateToken
    }

    private func handleUpDown(isDecreasing: Bool) {
        let limitedNewValue = setpointService.calculateNewValue(
            currentValue: currentValue,
            step: step,
            minValue: minValue,
            maxValue: maxValue,
            isDecreasing: isDecreasing
        )

        guard limitedNewValue != currentValue else {
            // nothing to update, skip sending value
            return
        }

        localValue = limitedNewValue
        let numberState = NumberState(value: limitedNewValue, unit: unit)

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
        SetpointRow(
            widget: widget,
            title: widget.labelText ?? widget.label,
            minValue: widget.minValue,
            maxValue: widget.maxValue,
            step: widget.step,
            stateValue: widget.stateValueAsNumberState?.value,
            labelValue: widget.labelValue,
            unit: widget.unit,
            stateToken: widget.item?.state ?? widget.state
        )
    }
}
