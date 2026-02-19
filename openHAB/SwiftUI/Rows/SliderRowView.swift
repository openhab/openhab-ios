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

private struct SliderRowConfig {
    let input: SliderRowInput
    let widgetVersion: Int
    let iconWidget: OpenHABWidget
    let fallbackSymbol: SFSymbol?
    let commandWidget: OpenHABWidget
    let viewModel: SitemapPageViewModel
}

@MainActor
private func makeSliderRowContent(_ config: SliderRowConfig) -> SliderRowContent {
    SliderRowContent(
        input: config.input,
        widgetVersion: config.widgetVersion,
        iconWidget: config.iconWidget,
        fallbackSymbol: config.fallbackSymbol,
        onToggleSwitch: { command in
            config.viewModel.sendCommand(command, for: config.commandWidget)
        },
        onCancelPending: { key in
            if let item = config.commandWidget.item {
                config.viewModel.cancelPendingCommand(for: item, key: key)
            } else {
                config.viewModel.cancelPendingCommand(for: config.commandWidget, key: key)
            }
        },
        onSendValue: { value, policy, phase, key in
            var numberState = config.commandWidget.stateValueAsNumberState
            numberState = numberState ?? NumberState(
                value: value,
                unit: config.commandWidget.unit,
                format: config.commandWidget.pattern ?? config.commandWidget.item?.stateDescription?.numberPattern
            )
            numberState?.value = value
            config.viewModel.sendToUpdate(item: config.commandWidget.item, state: numberState, policy: policy, phase: phase, key: key)
        }
    )
}

private struct SliderRowContent: View {
    let input: SliderRowInput
    let widgetVersion: Int
    let iconWidget: OpenHABWidget
    let fallbackSymbol: SFSymbol?
    let onToggleSwitch: (String) -> Void
    let onCancelPending: (String?) -> Void
    let onSendValue: (Double, WidgetCommandPolicy, WidgetCommandPhase, String?) -> Void

    /// Ephemeral local drag value. Server state remains authoritative outside active drag.
    @State private var dragValue: Double?
    @State private var isEditing = false
    @State private var dragStartVersion: Int?
    @State private var dragWidgetId: String?

    var body: some View {
        let displayedSliderValue = effectiveValue(state: input)
        HStack {
            if input.switchSupport {
                Button {
                    onToggleSwitch(displayedSliderValue <= input.displayState.minValue ? "ON" : "OFF")
                } label: {
                    labelContent(state: input)
                }
                .buttonStyle(.plain)
                .disabled(input.readOnly)
            } else {
                labelContent(state: input)
            }

            Slider(value: sliderBinding(state: input), in: input.sliderRange, step: input.step) { editing in
                isEditing = editing
                if editing {
                    dragWidgetId = input.widgetId
                    dragStartVersion = widgetVersion
                    dragValue = displayedSliderValue
                    return
                }

                // Always send the final value on release
                onCancelPending(input.sliderCommandKey)
                onSendValue(
                    displayedSliderValue,
                    .finalOnly,
                    .release,
                    input.sliderCommandKey
                )
                dragValue = nil
                dragStartVersion = nil
                dragWidgetId = nil
            }
            .disabled(input.readOnly)
        }
        .onAppear {
            isEditing = false
            dragValue = nil
            dragStartVersion = nil
            dragWidgetId = nil
        }
        .onChange(of: input.widgetId) { _ in
            isEditing = false
            dragValue = nil
            dragStartVersion = nil
            dragWidgetId = nil
        }
        .onChange(of: widgetVersion) { _ in
            guard isEditing else { return }
            // If server refresh advanced while dragging, only cancel when the server value diverges
            // meaningfully from the local drag value. This avoids jarring cancels on polling echoes.
            guard dragWidgetId == input.widgetId, let dragStartVersion else {
                isEditing = false
                dragValue = nil
                self.dragStartVersion = nil
                dragWidgetId = nil
                return
            }

            if widgetVersion != dragStartVersion {
                let threshold = max(input.step, 0.001)
                let currentDragValue = dragValue ?? input.serverValue
                let hasMeaningfulServerChange = abs(input.serverValue - currentDragValue) > threshold
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
    private func labelContent(state: SliderRowInput) -> some View {
        let displayedValue = effectiveValue(state: state)
        let currentValueText = currentValueText(state: state, value: displayedValue)
        HStack {
            IconView(widget: iconWidget, fallbackSymbol: fallbackSymbol)
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

    private func sliderBinding(state: SliderRowInput) -> Binding<Double> {
        Binding(
            get: { effectiveValue(state: state) },
            set: { newValue in
                dragValue = newValue

                // Send updates during drag if enabled (throttled)
                if isEditing, state.shouldSendUpdatesDuringMove {
                    onSendValue(
                        newValue,
                        WidgetCommandDefaults.slider,
                        .change,
                        state.sliderCommandKey
                    )
                }
            }
        )
    }

    private func effectiveValue(state: SliderRowInput) -> Double {
        isEditing ? (dragValue ?? state.serverValue) : state.serverValue
    }

    private func currentValueText(state: SliderRowInput, value: Double) -> String {
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

struct SliderRowInputView: View {
    let rowID: RowID
    let input: SliderRowInput
    var fallbackSymbol: SFSymbol?

    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        if let widget = viewModel.widget(for: rowID) {
            makeSliderRowContent(
                SliderRowConfig(
                    input: input,
                    widgetVersion: viewModel.widgetUpdateVersion(for: input.widgetId),
                    iconWidget: widget,
                    fallbackSymbol: fallbackSymbol,
                    commandWidget: widget,
                    viewModel: viewModel
                )
            )
        } else {
            EmptyView()
        }
    }
}

struct SliderRowView: View {
    @ObservedObject var widget: OpenHABWidget
    var fallbackSymbol: SFSymbol?

    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        let input = SliderRowInput.from(widget: widget)
        makeSliderRowContent(
            SliderRowConfig(
                input: input,
                widgetVersion: viewModel.widgetUpdateVersion(for: input.widgetId),
                iconWidget: widget,
                fallbackSymbol: fallbackSymbol,
                commandWidget: widget,
                viewModel: viewModel
            )
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
        PreviewWidgetFactory.slider(
            label: label,
            value: value,
            minValue: minValue,
            maxValue: maxValue,
            step: step,
            icon: icon,
            switchSupport: switchSupport
        )
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
