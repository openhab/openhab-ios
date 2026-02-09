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
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var settings: AppSettings
    var fallbackSymbol: SFSymbol?
    @State private var pendingValue: Double?
    @State private var viewModel: WidgetRowViewModel

    private var currentValue: Double {
        pendingValue ?? viewModel.adjustedValue
    }

    private var currentValueText: String {
        currentValue.valueText(step: viewModel.step)
    }

    var valueBinding: Binding<Double> {
        .init(
            get: {
                pendingValue ?? viewModel.adjustedValue
            },
            set: { newValue in
                Logger.rowViews.info("SliderRow new value = \(newValue)")
                pendingValue = newValue
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    if pendingValue == newValue { // Ensure no new updates came in
                        widget.sendCommand(newValue.valueText(step: viewModel.step))
                        pendingValue = nil
                    }
                }
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
                    Logger.rowViews.info("SliderRow switch to ON")
                    widget.sendCommand(viewModel.maxValue.valueText(step: viewModel.step))
                } else {
                    Logger.rowViews.info("SliderRow switch to OFF")
                    widget.sendCommand(viewModel.minValue.valueText(step: viewModel.step))
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 3) {
            if viewModel.switchSupport {
                Toggle(isOn: stateBinding) {
                    HStack {
                        IconView(widget: widget, settings: settings, fallbackSymbol: fallbackSymbol)
                        VStack(alignment: .leading) {
                            TextLabelView(widget: widget, font: .caption, lineLimit: 2)
                            if pendingValue != nil {
                                Text(currentValueText)
                                    .font(.caption2)
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
                    IconView(widget: widget, settings: settings, fallbackSymbol: fallbackSymbol)
                    TextLabelView(widget: widget, font: .caption, lineLimit: 2)
                    Spacer()
                    if pendingValue != nil {
                        Text(currentValueText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        DetailTextLabelView(widget: widget)
                    }
                }.padding(.top, 8)
            }

            Slider(value: valueBinding, in: viewModel.minValue ... viewModel.maxValue, step: viewModel.step)
                .labelsHidden()
        }
        .onAppear {
            viewModel.update(from: widget)
        }
        .onChange(of: widget.item?.state, initial: false) { _, _ in
            viewModel.update(from: widget)
        }
    }

    init(widget: OpenHABWidget, fallbackSymbol: SFSymbol? = nil) {
        self.widget = widget
        self.fallbackSymbol = fallbackSymbol
        _viewModel = State(wrappedValue: WidgetRowViewModel(widget: widget))
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
                fallbackSymbol: .thermometerMedium
            )
            SliderRow(
                widget: PreviewWidgetFactory.slider(
                    label: "Dimmer",
                    value: 50,
                    switchSupport: true
                ),
                fallbackSymbol: .lightbulbFill
            )
        }
    }
}

#Preview("From UserData") {
    PreviewNavigationContainer {
        SliderRow(
            widget: UserData(preview: true).widgets[3],
            fallbackSymbol: .sliderHorizontal3
        )
    }
}
