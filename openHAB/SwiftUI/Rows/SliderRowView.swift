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

    /// Pending value while user is dragging; nil when not actively changing
    @State private var pendingValue: Double?
    @State private var isEditing = false

    private var sliderCommandKey: String {
        "slider-\(widget.widgetId)"
    }

    var body: some View {
        let displayState = widget.displayState
        let currentValue = currentValue(displayState: displayState)
        HStack {
            if widget.switchSupport {
                Button {
                    viewModel.sendCommand(currentValue <= displayState.minValue ? "ON" : "OFF", for: widget)
                } label: {
                    labelContent(displayState: displayState)
                }
                .buttonStyle(.plain)
                .disabled(widget.readOnly ?? false)
            } else {
                labelContent(displayState: displayState)
            }

            Slider(value: valueBinding(displayState: displayState), in: sliderRange(displayState: displayState), step: widget.step) { editing in
                isEditing = editing
                if !editing {
                    // Always send the final value on release
                    if let value = pendingValue {
                        if let item = widget.item {
                            viewModel.cancelPendingCommand(for: item, key: sliderCommandKey)
                        } else {
                            viewModel.cancelPendingCommand(for: widget, key: sliderCommandKey)
                        }
                        sendSliderUpdate(value, policy: .immediate, key: sliderCommandKey)
                    }
                    // Keep pendingValue set until server responds to avoid visual jump
                    // Fallback: clear after delay if server doesn't respond
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(2000))
                        if !isEditing, pendingValue != nil {
                            pendingValue = nil
                        }
                    }
                }
            }
            .disabled(widget.readOnly ?? false)
        }
        .onChange(of: displayState.adjustedValue) { _ in
            // Clear pending value only when server confirms our value (not intermediate responses)
            if !isEditing, let pending = pendingValue,
               abs(displayState.adjustedValue - pending) < max(widget.step * 0.5, 0.01) {
                pendingValue = nil
            }
        }
        .onAppear {
            pendingValue = nil
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

            // Show current slider value (pendingValue while dragging, otherwise widget value)
            Text(pendingValue != nil ? currentValueText : (displayState.labelValue ?? currentValueText))
                .ohTextToken(.rowValueCallout)
                .foregroundStyle(widget.valuecolor.isEmpty ? Color(uiColor: UIColor.ohSecondaryLabel) : Color(fromString: widget.valuecolor))
        }
        .contentShape(Rectangle())
    }

    private func sendSliderUpdate(_ newValue: Double,
                                  policy: WidgetCommandPolicy,
                                  key: String?) {
        var numberState = widget.stateValueAsNumberState
        numberState = numberState ?? NumberState(
            value: newValue,
            unit: widget.unit,
            format: widget.item?.stateDescription?.numberPattern
        )
        numberState?.value = newValue
        viewModel.sendToUpdate(item: widget.item, state: numberState, policy: policy, key: key)
    }

    private func sliderRange(displayState: WidgetDisplayState) -> ClosedRange<Double> {
        displayState.minValue ... displayState.maxValue
    }

    private func currentValue(displayState: WidgetDisplayState) -> Double {
        pendingValue ?? displayState.adjustedValue
    }

    private func currentValueText(displayState: WidgetDisplayState) -> String {
        let currentValue = currentValue(displayState: displayState)
        if let numberPattern = widget.item?.stateDescription?.numberPattern, !numberPattern.isEmpty {
            let formatted = NumberState(
                value: currentValue,
                unit: widget.unit,
                format: numberPattern
            ).toString(locale: Locale.current)
            if !formatted.isEmpty {
                return formatted
            }
        }
        return currentValue.valueText(step: widget.step)
    }

    private func valueBinding(displayState: WidgetDisplayState) -> Binding<Double> {
        Binding(
            get: { pendingValue ?? displayState.adjustedValue },
            set: { newValue in
                pendingValue = newValue

                // Send updates during drag if enabled (throttled)
                if widget.shouldUseSliderUpdatesDuringMove() {
                    sendSliderUpdate(
                        newValue,
                        policy: WidgetCommandDefaults.slider,
                        key: sliderCommandKey
                    )
                }
            }
        )
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
