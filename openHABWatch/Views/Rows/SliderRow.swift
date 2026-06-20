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
    let stateToken: String
    @Environment(AppSettings.self) var settings
    var fallbackSymbol: SFSymbol?
    @State private var pendingValue: Double?
    @State private var viewModel: WidgetRowViewModel
    @State private var commandSender = WidgetCommandDispatcher()

    private var currentValue: Double {
        pendingValue ?? viewModel.adjustedValue
    }

    private var currentValueText: String {
        formattedValue(for: currentValue, locale: Locale.current)
    }

    var valueBinding: Binding<Double> {
        .init(
            get: {
                pendingValue ?? viewModel.adjustedValue
            },
            set: { newValue in
                Logger.rowViews.info("SliderRow new value = \(newValue)")
                pendingValue = newValue
                commandSender.send(
                    formattedValue(for: newValue, locale: Locale(identifier: "US")),
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
                viewModel.adjustedValue > viewModel.minValue
            },
            set: { newValue in
                if newValue {
                    commandSender.send(
                        formattedValue(for: viewModel.maxValue, locale: Locale(identifier: "US")),
                        for: widget,
                        policy: .immediate,
                        key: "slider-toggle"
                    )
                } else {
                    commandSender.send(
                        formattedValue(for: viewModel.minValue, locale: Locale(identifier: "US")),
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
            if viewModel.switchSupport {
                Toggle(isOn: stateBinding) {
                    HStack {
                        WatchIconView(model: widget.iconRenderModel(fallbackSymbol: fallbackSymbol), settings: settings)
                        VStack(alignment: .leading) {
                            WatchLabelText(text: viewModel.labelText, labelColor: widget.labelcolor)
                            if pendingValue != nil {
                                Text(currentValueText)
                                    .watchTextStyle(.secondary)
                                    .foregroundStyle(.secondary)
                            } else {
                                DetailTextLabelView(text: viewModel.labelValue, valueColor: widget.valuecolor)
                            }
                        }
                    }
                }
                .padding(.trailing)
                .cornerRadius(5)
            } else {
                HStack {
                    WatchIconView(model: widget.iconRenderModel(fallbackSymbol: fallbackSymbol), settings: settings)
                    WatchLabelText(text: viewModel.labelText, labelColor: widget.labelcolor)
                    Spacer()
                    if pendingValue != nil {
                        Text(currentValueText)
                            .watchTextStyle(.secondary)
                            .foregroundStyle(.secondary)
                    } else {
                        DetailTextLabelView(text: viewModel.labelValue, valueColor: widget.valuecolor)
                    }
                }.padding(.top, 8)
            }

            Slider(value: valueBinding, in: viewModel.minValue ... viewModel.maxValue, step: viewModel.step)
                .labelsHidden()
                .accessibilityLabel(viewModel.labelText)
                .accessibilityValue(currentValueText)
        }
        .accessibilityElement(children: .contain)
        .onChange(of: stateToken, initial: false) { _, _ in
            viewModel.update(from: widget)
            pendingValue = nil
        }
    }

    init(widget: OpenHABWidget, stateToken: String, fallbackSymbol: SFSymbol? = nil) {
        self.widget = widget
        self.stateToken = stateToken
        self.fallbackSymbol = fallbackSymbol
        _viewModel = State(wrappedValue: WidgetRowViewModel(widget: widget))
    }

    private func formattedValue(for value: Double, locale: Locale) -> String {
        if let numberPattern = widget.item?.stateDescription?.numberPattern,
           !numberPattern.isEmpty {
            return NumberState(
                value: value,
                unit: widget.unit,
                format: numberPattern
            ).toString(locale: locale)
        }
        return value.valueText(step: viewModel.step)
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
            stateToken: "75",
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
            stateToken: "16",
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
            stateToken: "50",
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
                stateToken: "75",
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
                stateToken: "21",
                fallbackSymbol: .thermometerMedium
            )
            SliderRow(
                widget: PreviewWidgetFactory.slider(
                    label: "Dimmer",
                    value: 50,
                    switchSupport: true
                ),
                stateToken: "50",
                fallbackSymbol: .lightbulbFill
            )
        }
    }
}

#Preview("From UserData") {
    PreviewNavigationContainer {
        SliderRow(
            widget: UserData(preview: true).widgets[3],
            stateToken: "0",
            fallbackSymbol: .sliderHorizontal3
        )
    }
}
