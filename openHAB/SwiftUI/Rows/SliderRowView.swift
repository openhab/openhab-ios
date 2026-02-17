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
import SFSafeSymbols
import SwiftUI

struct SliderRowView: View {
    @ObservedObject var widget: OpenHABWidget
    var fallbackSymbol: SFSymbol?

    @EnvironmentObject var viewModel: SitemapPageViewModel

    /// Local slider thumb value. Synced from server state when not editing.
    @State private var sliderValue: Double = 0
    @State private var isEditing = false

    private var sliderCommandKey: String {
        "slider-\(widget.widgetId)"
    }

    var body: some View {
        let displayState = widget.displayState
        let displayedSliderValue = isEditing ? sliderValue : serverSliderValue(displayState: displayState)
        HStack {
            if widget.switchSupport {
                Button {
                    viewModel.sendCommand(displayedSliderValue <= displayState.minValue ? "ON" : "OFF", for: widget)
                } label: {
                    labelContent(displayState: displayState)
                }
                .buttonStyle(.plain)
                .disabled(widget.readOnly ?? false)
            } else {
                labelContent(displayState: displayState)
            }

            Slider(value: sliderBinding(displayState: displayState), in: sliderRange(displayState: displayState), step: widget.step) { editing in
                isEditing = editing
                if !editing {
                    // Always send the final value on release
                    if let item = widget.item {
                        viewModel.cancelPendingCommand(for: item, key: sliderCommandKey)
                    } else {
                        viewModel.cancelPendingCommand(for: widget, key: sliderCommandKey)
                    }
                    sendSliderUpdate(
                        sliderValue,
                        policy: .finalOnly,
                        phase: .release,
                        key: sliderCommandKey
                    )
                }
            }
            .disabled(widget.readOnly ?? false)
        }
        .onAppear {
            sliderValue = serverSliderValue(displayState: displayState)
            isEditing = false
        }
    }

    @ViewBuilder
    private func labelContent(displayState: WidgetDisplayState) -> some View {
        let currentValueText = currentValueText(displayState: displayState)
        HStack {
            IconView(widget: widget, fallbackSymbol: fallbackSymbol)
                .frame(width: 32, height: 32)

            if !displayState.labelText.isEmpty {
                let labelText = displayState.labelText
                Text(labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
            }

            Spacer()

            // Show local value while dragging, otherwise use the server label value.
            Text(isEditing ? currentValueText : (displayState.labelValue ?? currentValueText))
                .ohTextToken(.rowValueCallout)
                .foregroundStyle(widget.valuecolor.isEmpty ? Color(uiColor: UIColor.ohSecondaryLabel) : Color(fromString: widget.valuecolor))
        }
        .contentShape(Rectangle())
    }

    private func sendSliderUpdate(_ newValue: Double,
                                  policy: WidgetCommandPolicy,
                                  phase: WidgetCommandPhase = .change,
                                  key: String?) {
        var numberState = widget.stateValueAsNumberState
        numberState = numberState ?? NumberState(
            value: newValue,
            unit: widget.unit,
            format: widget.item?.stateDescription?.numberPattern
        )
        numberState?.value = newValue
        viewModel.sendToUpdate(item: widget.item, state: numberState, policy: policy, phase: phase, key: key)
    }

    private func sliderRange(displayState: WidgetDisplayState) -> ClosedRange<Double> {
        displayState.minValue ... displayState.maxValue
    }

    private func sliderBinding(displayState: WidgetDisplayState) -> Binding<Double> {
        Binding(
            get: { isEditing ? sliderValue : serverSliderValue(displayState: displayState) },
            set: { newValue in
                sliderValue = newValue

                // Send updates during drag if enabled (throttled)
                if isEditing, widget.shouldUseSliderUpdatesDuringMove() {
                    sendSliderUpdate(
                        newValue,
                        policy: WidgetCommandDefaults.slider,
                        key: sliderCommandKey
                    )
                }
            }
        )
    }

    private func serverSliderValue(displayState: WidgetDisplayState) -> Double {
        let numberPattern = widget.item?.stateDescription?.numberPattern

        if let labelValue = displayState.labelValue, !labelValue.isEmpty {
            return adjustedToStep(labelValue.parseAsNumber(format: numberPattern).value, displayState: displayState)
        }

        let effectiveState = displayState.effectiveState
        if !effectiveState.isEmpty,
           effectiveState != "NULL",
           effectiveState != "UNDEF",
           effectiveState.caseInsensitiveCompare("undefined") != .orderedSame {
            return adjustedToStep(effectiveState.parseAsNumber(format: numberPattern).value, displayState: displayState)
        }

        return displayState.adjustedValue
    }

    private func adjustedToStep(_ raw: Double, displayState: WidgetDisplayState) -> Double {
        let range = displayState.minValue ... displayState.maxValue
        let clamped = raw.clamped(to: range)

        guard displayState.step > 0 else {
            return clamped
        }

        var adjusted = floor((clamped - displayState.minValue) / displayState.step) * displayState.step
        adjusted += displayState.minValue
        return adjusted.clamped(to: range)
    }

    private func currentValueText(displayState: WidgetDisplayState) -> String {
        if let numberPattern = widget.item?.stateDescription?.numberPattern, !numberPattern.isEmpty {
            let formatted = NumberState(
                value: sliderValue,
                unit: widget.unit,
                format: numberPattern
            ).toString(locale: Locale.current)
            if !formatted.isEmpty {
                return formatted
            }
        }
        return sliderValue.valueText(step: widget.step)
    }
}

// MARK: - Preview Helpers

#if DEBUG
private extension SliderRowView {
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

#Preview("Default Range (0-100)") {
    PreviewList {
        SliderRowView(
            widget: SliderRowView.createPreviewWidget(
                label: "Brightness",
                value: 75
            ),
            fallbackSymbol: .sliderHorizontal3
        )
    }
}

#Preview("Custom Range (minValue)") {
    PreviewList {
        SliderRowView(
            widget: SliderRowView.createPreviewWidget(
                label: "Temperature",
                value: 21,
                minValue: 16,
                maxValue: 28,
                step: 0.5
            ),
            fallbackSymbol: .thermometerMedium
        )
    }
}

#Preview("With Switch Support") {
    PreviewList {
        SliderRowView(
            widget: SliderRowView.createPreviewWidget(
                label: "Dimmer",
                value: 50,
                switchSupport: true
            ),
            fallbackSymbol: .lightbulbFill
        )
    }
}

#Preview("All Scenarios") {
    PreviewList {
        SliderRowView(
            widget: SliderRowView.createPreviewWidget(
                label: "Brightness",
                value: 75
            ),
            fallbackSymbol: .sliderHorizontal3
        )
        SliderRowView(
            widget: SliderRowView.createPreviewWidget(
                label: "Temperature",
                value: 21,
                minValue: 16,
                maxValue: 28,
                step: 0.5
            ),
            fallbackSymbol: .thermometerMedium
        )
        SliderRowView(
            widget: SliderRowView.createPreviewWidget(
                label: "Volume",
                value: 30,
                minValue: 0,
                maxValue: 100,
                icon: "soundvolume"
            ),
            fallbackSymbol: .speakerWave2Fill
        )
        SliderRowView(
            widget: SliderRowView.createPreviewWidget(
                label: "Dimmer",
                value: 50,
                switchSupport: true
            ),
            fallbackSymbol: .lightbulbFill
        )
    }
}

#Preview("From PreviewConstants") {
    PreviewList {
        SliderRowView(
            widget: PreviewConstants.openHABSitemapPage!.widgets[3],
            fallbackSymbol: .sliderHorizontal3
        )
    }
}
