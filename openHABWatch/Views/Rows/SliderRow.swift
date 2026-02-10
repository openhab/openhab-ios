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

struct SliderRow: View {
    let widget: OpenHABWidget
    let adjustedValue: Double
    let minValue: Double
    let maxValue: Double
    let step: Double
    let switchSupport: Bool
    @EnvironmentObject var settings: AppSettings
    var fallbackSymbol: SFSymbol?
    @State private var pendingValue: Double?
    @State private var commandSender = WidgetCommandSender()

    private var currentValue: Double {
        pendingValue ?? adjustedValue
    }

    private var currentValueText: String {
        currentValue.valueText(step: step)
    }

    var valueBinding: Binding<Double> {
        .init(
            get: {
                pendingValue ?? adjustedValue
            },
            set: { newValue in
                Logger.rowViews.info("SliderRow new value = \(newValue)")
                pendingValue = newValue
                commandSender.send(
                    newValue.valueText(step: step),
                    for: widget,
                    policy: WidgetCommandDefaults.slider,
                    key: "slider-value"
                )
            }
        )
    }

    private var stateBinding: Binding<Bool> {
        Binding<Bool>(
            get: {
                adjustedValue > minValue
            },
            set: { newValue in
                if newValue {
                    commandSender.send(
                        maxValue.valueText(step: step),
                        for: widget,
                        policy: .immediate,
                        key: "slider-toggle"
                    )
                } else {
                    commandSender.send(
                        minValue.valueText(step: step),
                        for: widget,
                        policy: .immediate,
                        key: "slider-toggle"
                    )
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 3) {
            if switchSupport {
                Toggle(isOn: stateBinding) {
                    HStack {
                        WatchIconView(model: widget.iconRenderModel(fallbackSymbol: fallbackSymbol), settings: settings)
                        VStack(alignment: .leading) {
                            WatchLabelText(widget: widget)
                            if pendingValue != nil {
                                Text(currentValueText)
                                    .font(WatchTypography.secondaryFont)
                                    .lineLimit(WatchTypography.secondaryLineLimit)
                                    .minimumScaleFactor(WatchTypography.secondaryMinScale)
                                    .truncationMode(.tail)
                                    .foregroundStyle(.secondary)
                            } else {
                                DetailTextLabelView(widget: widget)
                            }
                        }
                    }
                }
                .padding(.trailing)
                .cornerRadius(5)
            } else {
                HStack {
                    WatchIconView(model: widget.iconRenderModel(fallbackSymbol: fallbackSymbol), settings: settings)
                    WatchLabelText(widget: widget)
                    Spacer()
                    if pendingValue != nil {
                        Text(currentValueText)
                            .font(WatchTypography.secondaryFont)
                            .lineLimit(WatchTypography.secondaryLineLimit)
                            .minimumScaleFactor(WatchTypography.secondaryMinScale)
                            .truncationMode(.tail)
                            .foregroundStyle(.secondary)
                    } else {
                        DetailTextLabelView(widget: widget)
                    }
                }.padding(.top, 8)
            }

            Slider(value: valueBinding, in: minValue ... maxValue, step: step)
                .labelsHidden()
        }
        .onChange(of: adjustedValue, initial: false) { _, _ in
            pendingValue = nil
        }
    }

    init(widget: OpenHABWidget,
         adjustedValue: Double,
         minValue: Double,
         maxValue: Double,
         step: Double,
         switchSupport: Bool,
         fallbackSymbol: SFSymbol? = nil) {
        self.widget = widget
        self.adjustedValue = adjustedValue
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
        self.switchSupport = switchSupport
        self.fallbackSymbol = fallbackSymbol
    }
}

// MARK: - Previews

#Preview("Default Range") {
    PreviewNavigationContainer {
        SliderRow(
            widget: PreviewWidgetFactory.slider(
                label: "Brightness",
                value: 75
            ),
            adjustedValue: 75,
            minValue: 0,
            maxValue: 100,
            step: 1,
            switchSupport: false,
            fallbackSymbol: .sliderHorizontal3
        )
    }
}

#Preview("Custom Range (minValue)") {
    PreviewNavigationContainer {
        SliderRow(
            widget: PreviewWidgetFactory.slider(
                label: "Temperature",
                value: 16,
                minValue: 16,
                maxValue: 28,
                step: 0.5
            ),
            adjustedValue: 16,
            minValue: 16,
            maxValue: 28,
            step: 0.5,
            switchSupport: false,
            fallbackSymbol: .thermometerMedium
        )
    }
}

#Preview("With Switch Support") {
    PreviewNavigationContainer {
        SliderRow(
            widget: PreviewWidgetFactory.slider(
                label: "Dimmer",
                value: 50,
                switchSupport: true
            ),
            adjustedValue: 50,
            minValue: 0,
            maxValue: 100,
            step: 1,
            switchSupport: true,
            fallbackSymbol: .lightbulbFill
        )
    }
}

#Preview("All Scenarios") {
    PreviewNavigationContainer {
        List {
            SliderRow(
                widget: PreviewWidgetFactory.slider(
                    label: "Brightness",
                    value: 75
                ),
                adjustedValue: 75,
                minValue: 0,
                maxValue: 100,
                step: 1,
                switchSupport: false,
                fallbackSymbol: .sliderHorizontal3
            )
            SliderRow(
                widget: PreviewWidgetFactory.slider(
                    label: "Temperature",
                    value: 21,
                    minValue: 16,
                    maxValue: 28,
                    step: 0.5
                ),
                adjustedValue: 21,
                minValue: 16,
                maxValue: 28,
                step: 0.5,
                switchSupport: false,
                fallbackSymbol: .thermometerMedium
            )
            SliderRow(
                widget: PreviewWidgetFactory.slider(
                    label: "Dimmer",
                    value: 50,
                    switchSupport: true
                ),
                adjustedValue: 50,
                minValue: 0,
                maxValue: 100,
                step: 1,
                switchSupport: true,
                fallbackSymbol: .lightbulbFill
            )
        }
    }
}

#Preview("From UserData") {
    PreviewNavigationContainer {
        SliderRow(
            widget: UserData(preview: true).widgets[3],
            adjustedValue: 0,
            minValue: 0,
            maxValue: 100,
            step: 1,
            switchSupport: false,
            fallbackSymbol: .sliderHorizontal3
        )
    }
}
