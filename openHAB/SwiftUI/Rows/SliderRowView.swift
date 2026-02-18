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

private struct SliderRowState {
    let widgetId: String
    let displayState: WidgetDisplayState
    let numberPattern: String?
    let unit: String?
    let readOnly: Bool
    let switchSupport: Bool
    let step: Double
    let labelColor: String
    let valueColor: String
    let shouldSendUpdatesDuringMove: Bool
    let serverValue: Double

    var sliderCommandKey: String {
        "slider-\(widgetId)"
    }

    var sliderRange: ClosedRange<Double> {
        displayState.minValue ... displayState.maxValue
    }

    static func from(widget: OpenHABWidget) -> SliderRowState {
        let displayState = widget.displayState
        let numberPattern = if let pattern = widget.pattern, !pattern.isEmpty {
            pattern
        } else {
            widget.item?.stateDescription?.numberPattern
        }
        // For item-backed sliders, adjustedValue is the most stable source of truth for position.
        // It is derived from the item state and avoids stale text/state snapshots.
        let serverValue = if widget.item != nil {
            displayState.adjustedValue
        } else {
            parseServerValue(displayState: displayState, numberPattern: numberPattern)
        }

        return SliderRowState(
            widgetId: widget.widgetId,
            displayState: displayState,
            numberPattern: numberPattern,
            unit: widget.unit,
            readOnly: widget.readOnly ?? false,
            switchSupport: widget.switchSupport,
            step: widget.step,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            shouldSendUpdatesDuringMove: widget.shouldUseSliderUpdatesDuringMove(),
            serverValue: adjustedToStep(serverValue, displayState: displayState)
        )
    }

    private static func parseServerValue(displayState: WidgetDisplayState, numberPattern: String?) -> Double {
        let effectiveState = displayState.effectiveState
        if !effectiveState.isEmpty,
           effectiveState != "NULL",
           effectiveState != "UNDEF",
           effectiveState.caseInsensitiveCompare("undefined") != .orderedSame {
            return effectiveState.parseAsNumber(format: numberPattern).value
        }

        // Fallback for widgets whose item state is not directly usable but label value is present.
        if let labelValue = displayState.labelValue, !labelValue.isEmpty {
            return labelValue.parseAsNumber(format: numberPattern).value
        }

        return displayState.adjustedValue
    }

    private static func adjustedToStep(_ raw: Double, displayState: WidgetDisplayState) -> Double {
        let range = displayState.minValue ... displayState.maxValue
        let clamped = raw.clamped(to: range)
        guard displayState.step > 0 else { return clamped }

        var adjusted = floor((clamped - displayState.minValue) / displayState.step) * displayState.step
        adjusted += displayState.minValue
        return adjusted.clamped(to: range)
    }
}

struct SliderRowView: View {
    @ObservedObject var widget: OpenHABWidget
    var fallbackSymbol: SFSymbol?

    @EnvironmentObject var viewModel: SitemapPageViewModel

    /// Ephemeral local drag value. Server state remains authoritative outside active drag.
    @State private var dragValue: Double?
    @State private var isEditing = false
    @State private var dragStartVersion: Int?
    @State private var dragWidgetId: String?

    var body: some View {
        let state = SliderRowState.from(widget: widget)
        let widgetVersion = viewModel.widgetUpdateVersion(for: state.widgetId)
        let displayedSliderValue = effectiveValue(state: state)
        HStack {
            if state.switchSupport {
                Button {
                    viewModel.sendCommand(displayedSliderValue <= state.displayState.minValue ? "ON" : "OFF", for: widget)
                } label: {
                    labelContent(state: state)
                }
                .buttonStyle(.plain)
                .disabled(state.readOnly)
            } else {
                labelContent(state: state)
            }

            Slider(value: sliderBinding(state: state), in: state.sliderRange, step: state.step) { editing in
                isEditing = editing
                if editing {
                    dragWidgetId = state.widgetId
                    dragStartVersion = widgetVersion
                    dragValue = displayedSliderValue
                    return
                }

                // Always send the final value on release
                if let item = widget.item {
                    viewModel.cancelPendingCommand(for: item, key: state.sliderCommandKey)
                } else {
                    viewModel.cancelPendingCommand(for: widget, key: state.sliderCommandKey)
                }
                sendSliderUpdate(
                    displayedSliderValue,
                    policy: .finalOnly,
                    phase: .release,
                    key: state.sliderCommandKey
                )
                dragValue = nil
                dragStartVersion = nil
                dragWidgetId = nil
            }
            .disabled(state.readOnly)
        }
        .onAppear {
            isEditing = false
            dragValue = nil
            dragStartVersion = nil
            dragWidgetId = nil
        }
        .onChange(of: state.widgetId) { _ in
            isEditing = false
            dragValue = nil
            dragStartVersion = nil
            dragWidgetId = nil
        }
        .onChange(of: widgetVersion) { _ in
            guard isEditing else { return }
            // If server refresh advanced while dragging, only cancel when the server value diverges
            // meaningfully from the local drag value. This avoids jarring cancels on polling echoes.
            guard dragWidgetId == state.widgetId, let dragStartVersion else {
                isEditing = false
                dragValue = nil
                self.dragStartVersion = nil
                dragWidgetId = nil
                return
            }

            if widgetVersion != dragStartVersion {
                let threshold = max(state.step, 0.001)
                let currentDragValue = dragValue ?? state.serverValue
                let hasMeaningfulServerChange = abs(state.serverValue - currentDragValue) > threshold
                if hasMeaningfulServerChange {
                    isEditing = false
                    dragValue = nil
                    self.dragStartVersion = nil
                    dragWidgetId = nil
                } else {
                    // Accept this refresh as equivalent while preserving current drag interaction.
                    self.dragStartVersion = widgetVersion
                }
            }
        }
    }

    @ViewBuilder
    private func labelContent(state: SliderRowState) -> some View {
        let displayedValue = effectiveValue(state: state)
        let currentValueText = currentValueText(state: state, value: displayedValue)
        HStack {
            IconView(widget: widget, fallbackSymbol: fallbackSymbol)
                .frame(width: 32, height: 32)

            if !state.displayState.labelText.isEmpty {
                let labelText = state.displayState.labelText
                Text(labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(state.labelColor.isEmpty ? .primary : Color(fromString: state.labelColor))
            }

            Spacer()

            // Show local value while dragging, otherwise use the server label value.
            Text(isEditing ? currentValueText : (state.displayState.labelValue ?? currentValueText))
                .ohTextToken(.rowValueCallout)
                .monospacedDigit()
                .foregroundStyle(state.valueColor.isEmpty ? Color(uiColor: UIColor.ohSecondaryLabel) : Color(fromString: state.valueColor))
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
            format: widget.pattern ?? widget.item?.stateDescription?.numberPattern
        )
        numberState?.value = newValue
        viewModel.sendToUpdate(item: widget.item, state: numberState, policy: policy, phase: phase, key: key)
    }

    private func sliderBinding(state: SliderRowState) -> Binding<Double> {
        Binding(
            get: { effectiveValue(state: state) },
            set: { newValue in
                dragValue = newValue

                // Send updates during drag if enabled (throttled)
                if isEditing, state.shouldSendUpdatesDuringMove {
                    sendSliderUpdate(
                        newValue,
                        policy: WidgetCommandDefaults.slider,
                        key: state.sliderCommandKey
                    )
                }
            }
        )
    }

    private func effectiveValue(state: SliderRowState) -> Double {
        isEditing ? (dragValue ?? state.serverValue) : state.serverValue
    }

    private func currentValueText(state: SliderRowState, value: Double) -> String {
        if let numberPattern = state.numberPattern, !numberPattern.isEmpty {
            let formatted = NumberState(
                value: value,
                unit: state.unit,
                format: numberPattern
            ).toString(locale: Locale.current)
            if !formatted.isEmpty {
                return formatted
            }
        }
        return value.valueText(step: state.step)
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
