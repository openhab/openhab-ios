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
    var valueBinding: Binding<Double> {
        .init(
            get: {
                pendingValue ?? widget.adjustedValue
            },
            set: { newValue in
                Logger.rowViews.info("SliderRow new value = \(newValue)")
                pendingValue = newValue
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    if pendingValue == newValue { // Ensure no new updates came in
                        widget.sendCommand(newValue.valueText(step: widget.step))
                        pendingValue = nil
                    }
                }
            }
        )
    }

    private var stateBinding: Binding<Bool> {
        Binding<Bool>(
            get: {
                widget.adjustedValue > widget.minValue
            },
            set: { newValue in
                if newValue {
                    Logger.rowViews.info("SliderRow switch to ON")
                    widget.sendCommand(widget.maxValue.valueText(step: widget.step))
                } else {
                    Logger.rowViews.info("SliderRow switch to OFF")
                    widget.sendCommand(widget.minValue.valueText(step: widget.step))
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 3) {
            if widget.switchSupport {
                Toggle(isOn: stateBinding) {
                    HStack {
                        IconView(widget: widget, settings: settings, fallbackSymbol: fallbackSymbol)
                        VStack(alignment: .leading) {
                            TextLabelView(widget: widget, font: .caption, lineLimit: 2)
                            DetailTextLabelView(widget: widget)
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
                    DetailTextLabelView(widget: widget)
                }.padding(.top, 8)
            }

            Slider(value: valueBinding, in: widget.minValue ... widget.maxValue, step: widget.step)
                .labelsHidden()
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
private extension SliderRow {
    static func createPreviewWidget(label: String,
                                    value: Double? = nil,
                                    minValue: Double = 0.0,
                                    maxValue: Double = 100.0,
                                    step: Double = 1.0,
                                    icon: String = "slider",
                                    switchSupport: Bool = false) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = UUID().uuidString
        widget.type = .slider
        widget.icon = icon
        widget.minValue = minValue
        widget.maxValue = maxValue
        widget.step = step
        widget.switchSupport = switchSupport

        if let value {
            widget.label = "\(label) [\(Int(value))]"
        } else {
            widget.label = label
        }

        let item = OpenHABItem(
            name: "Preview_\(label.replacingOccurrences(of: " ", with: "_"))",
            type: "Dimmer",
            state: value.map { String($0) } ?? "NULL",
            link: "",
            label: label,
            groupType: nil,
            stateDescription: nil,
            commandDescription: nil,
            members: [],
            category: nil,
            options: nil
        )
        widget.item = item

        return widget
    }
}
#endif

// MARK: - Previews

#Preview("Default Range") {
    SliderRow(
        widget: SliderRow.createPreviewWidget(
            label: "Brightness",
            value: 75
        ),
        fallbackSymbol: .sliderHorizontal3
    )
    .environmentObject(AppSettings())
}

#Preview("Custom Range (minValue)") {
    SliderRow(
        widget: SliderRow.createPreviewWidget(
            label: "Temperature",
            value: 16,
            minValue: 16,
            maxValue: 28,
            step: 0.5
        ),
        fallbackSymbol: .thermometerMedium
    )
    .environmentObject(AppSettings())
}

#Preview("With Switch Support") {
    SliderRow(
        widget: SliderRow.createPreviewWidget(
            label: "Dimmer",
            value: 50,
            switchSupport: true
        ),
        fallbackSymbol: .lightbulbFill
    )
    .environmentObject(AppSettings())
}

#Preview("All Scenarios") {
    List {
        SliderRow(
            widget: SliderRow.createPreviewWidget(
                label: "Brightness",
                value: 75
            ),
            fallbackSymbol: .sliderHorizontal3
        )
        SliderRow(
            widget: SliderRow.createPreviewWidget(
                label: "Temperature",
                value: 21,
                minValue: 16,
                maxValue: 28,
                step: 0.5
            ),
            fallbackSymbol: .thermometerMedium
        )
        SliderRow(
            widget: SliderRow.createPreviewWidget(
                label: "Dimmer",
                value: 50,
                switchSupport: true
            ),
            fallbackSymbol: .lightbulbFill
        )
    }
    .environmentObject(AppSettings())
}

#Preview("From UserData") {
    SliderRow(
        widget: UserData(preview: true).widgets[3],
        fallbackSymbol: .sliderHorizontal3
    )
    .environmentObject(AppSettings())
}
