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
    let overrideValue: Double?
    let realTimeSliders: Bool
    let fallbackSymbol: SFSymbol?
    let viewModel: SitemapPageViewModel
}

@MainActor
private func makeSliderRowContent(_ config: SliderRowConfig) -> SliderRowContent {
    SliderRowContent(
        input: config.input,
        widgetVersion: config.widgetVersion,
        overrideValue: config.overrideValue,
        realTimeSliders: config.realTimeSliders,
        fallbackSymbol: config.fallbackSymbol,
        onToggleSwitch: { command in
            guard let itemName = config.input.itemName else { return }
            config.viewModel.sendCommand(command, for: itemName)
        },
        onCancelPending: { key in
            guard let itemName = config.input.itemName else { return }
            config.viewModel.cancelPendingCommand(for: itemName, key: key)
        },
        onSendValue: { value, policy, phase, key in
            guard let itemName = config.input.itemName else { return }
            // Publishing an override on a live update refreshes this row while the
            // finger is still down, and the slider then stops tracking.
            if phase == .release {
                config.viewModel.setSliderOverrideValue(value, for: itemName)
            }
            let numberState = NumberState(
                value: value,
                unit: config.input.unit,
                format: config.input.numberPattern
            )
            config.viewModel.sendToUpdate(itemname: itemName, state: numberState, policy: policy, phase: phase, key: key)
        }
    )
}

/// Confirmation delay for a real-time slider. The wait is not UI work, so it leaves the main actor.
/// `SliderRowContent`'s `.task` returns to the main actor before committing, and cancels this wait
/// when the row disappears or a newer gesture replaces it.
@concurrent
private func waitForSliderLiftConfirmation() async throws {
    try await Task.sleep(for: .seconds(SliderDragCoordinator.liftConfirmationDelay))
}

private struct SliderRowContent: View {
    let input: SliderRowInput
    let widgetVersion: Int
    let overrideValue: Double?
    let realTimeSliders: Bool
    let fallbackSymbol: SFSymbol?
    let onToggleSwitch: (String) -> Void
    let onCancelPending: (String?) -> Void
    let onSendValue: (Double, WidgetCommandPolicy, WidgetCommandPhase, String?) -> Void

    /// Finger contact and the values accepted during it. Server state stays authoritative afterwards.
    @State private var coordinator = SliderDragCoordinator()
    @State private var dragStartVersion: Int?
    @State private var dragWidgetId: String?
    @State private var liftToken: UUID?

    var body: some View {
        let displayedSliderValue = displayedValue(state: input)
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

            Slider(value: sliderBinding(state: input), in: input.sliderRange, step: input.safeStep) { editing in
                perform({ session in
                    session.editingChanged(editing, displayedValue: displayedSliderValue, now: Date())
                }, state: input)
            }
            .disabled(input.readOnly)
            // The Slider's own editing callback is unbalanced on iOS 26+ when `step` is set.
            // A simultaneous drag records real finger contact so a late callback cannot send again.
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        perform({ session in
                            session.fingerChanged(displayedValue: displayedSliderValue)
                        }, state: input)
                    }
                    .onEnded { _ in
                        scheduleLiftConfirmation()
                    }
            )
        }
        .onAppear {
            resetDragTracking()
        }
        .task(id: liftToken) {
            await confirmPendingLift()
        }
        .onChange(of: input.widgetId) {
            resetDragTracking()
        }
        .onChange(of: widgetVersion) {
            guard coordinator.isDragging else { return }
            if coordinator.fingerIsDown || coordinator.pendingLift {
                // The finger still owns the thumb. A realtime command goes out on an interval
                // while the thumb moves, and the server echo of that command arrives while the
                // finger is down. Treating it as an outside change cancels the drag.
                if dragWidgetId == input.widgetId {
                    dragStartVersion = widgetVersion
                }
                return
            }
            // If server refresh advanced while dragging, only cancel when the server value diverges
            // meaningfully from the local drag value. This avoids jarring cancels on polling echoes.
            guard dragWidgetId == input.widgetId, let dragStartVersion else {
                coordinator.cancel(now: Date())
                dragStartVersion = nil
                dragWidgetId = nil
                return
            }

            if widgetVersion != dragStartVersion {
                let threshold = max(input.step, 0.001)
                let currentDragValue = coordinator.dragValue ?? input.serverValue
                let hasMeaningfulServerChange = abs(input.serverValue - currentDragValue) > threshold
                if hasMeaningfulServerChange {
                    coordinator.cancel(now: Date())
                    self.dragStartVersion = nil
                    dragWidgetId = nil
                } else {
                    // Accept this refresh as equivalent while preserving current drag interaction.
                    self.dragStartVersion = widgetVersion
                }
            }
        }
    }

    private func resetDragTracking() {
        coordinator.reset()
        dragStartVersion = nil
        dragWidgetId = nil
        liftToken = nil
    }

    /// DragGesture can report the finger lifting when a live update refreshes the row.
    /// Confirm the lift only if the thumb does not move again within the confirmation window.
    /// Release-only drags publish nothing until the finger lifts, so that refresh does not
    /// happen and the slider's own release animation must not cancel the only command.
    private func scheduleLiftConfirmation() {
        perform({ session in
            _ = session.fingerMayHaveLifted(now: Date())
            return []
        }, state: input)
        guard coordinator.pendingLift else { return }

        let sendsDuringMove = input.sendsUpdatesDuringMove(realTimeSliders: realTimeSliders)
        if !sendsDuringMove {
            liftToken = nil
            perform({ session in
                session.commitPendingLift(
                    displayedValue: displayedValue(state: input),
                    now: Date()
                )
            }, state: input)
            return
        }

        // Replacing the token cancels the previous wait. `.task(id:)` starts the new one.
        liftToken = UUID()
    }

    private func confirmPendingLift() async {
        guard let token = liftToken else { return }
        do {
            try await waitForSliderLiftConfirmation()
        } catch {
            return
        }
        guard !Task.isCancelled, liftToken == token, coordinator.pendingLift else { return }
        perform({ session in
            session.commitPendingLift(
                displayedValue: displayedValue(state: input),
                now: Date()
            )
        }, state: input)
    }

    private func perform(_ update: (inout SliderDragCoordinator) -> [SliderDragCoordinator.Action],
                         state: SliderRowInput) {
        var session = coordinator
        let actions = update(&session)
        // The post-release burst calls this on every animation frame without changing
        // the session. Writing that copy back refreshes the row and fights the thumb.
        if coordinator != session {
            coordinator = session
        }
        if coordinator.isDragging, dragWidgetId == nil {
            dragWidgetId = state.widgetId
            dragStartVersion = widgetVersion
        }
        let sendsDuringMove = state.sendsUpdatesDuringMove(realTimeSliders: realTimeSliders)
        for action in actions {
            switch action {
            case let .change(value):
                guard sendsDuringMove else { continue }
                onSendValue(value, WidgetCommandDefaults.realtimeSlider, .change, state.sliderCommandKey)
            case let .release(value):
                onCancelPending(state.sliderCommandKey)
                onSendValue(value, .finalOnly, .release, state.sliderCommandKey)
                dragStartVersion = nil
                dragWidgetId = nil
            }
        }
        // The thumb moved again, or the lift was committed. Drop the wait so it cannot send later.
        if liftToken != nil, !coordinator.pendingLift {
            liftToken = nil
        }
    }

    @ViewBuilder
    private func labelContent(state: SliderRowInput) -> some View {
        let shownValue = displayedValue(state: state)
        let currentValueText = currentValueText(state: state, value: shownValue)
        RowViewWithIcon(input: state, fallbackSymbol: fallbackSymbol) {
            if !state.displayState.labelText.isEmpty {
                let labelText = state.displayState.labelText
                Text(labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(state.labelColor.isEmpty ? .primary : Color(fromString: state.labelColor))
            }

            Spacer()

            // Show local value while dragging, otherwise use the server label value.
            Text(coordinator.isDragging ? currentValueText : (state.displayState.labelValue ?? currentValueText))
                .ohTextToken(.rowValueCallout)
                .monospacedDigit()
                .foregroundStyle(state.valueColor.isEmpty ? Color(.secondaryLabel) : Color(fromString: state.valueColor))
        }
        .contentShape(Rectangle())
    }

    private func sliderBinding(state: SliderRowInput) -> Binding<Double> {
        Binding(
            get: { displayedValue(state: state) },
            set: { newValue in
                let displayed = displayedValue(state: state)
                perform({ session in
                    session.valueChanged(newValue, displayedValue: displayed, step: state.step, now: Date())
                }, state: state)
            }
        )
    }

    private func displayedValue(state: SliderRowInput) -> Double {
        if coordinator.isDragging, let dragValue = coordinator.dragValue {
            return dragValue
        }
        return overrideValue ?? state.serverValue
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

struct SliderRowView: View {
    let input: SliderRowInput
    var fallbackSymbol: SFSymbol?

    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        makeSliderRowContent(
            SliderRowConfig(
                input: input,
                widgetVersion: viewModel.widgetUpdateVersion(for: input.widgetId),
                overrideValue: viewModel.sliderOverrideValue(for: input.itemName),
                realTimeSliders: viewModel.realTimeSliders,
                fallbackSymbol: fallbackSymbol,
                viewModel: viewModel
            )
        )
    }
}

// MARK: - Preview Helpers

private extension SliderRowView {
    static func createPreviewInput(label: String,
                                   value: Double? = nil,
                                   minValue: Double = 0.0,
                                   maxValue: Double = 100.0,
                                   step: Double = 1.0,
                                   icon: String = "slider",
                                   switchSupport: Bool = false) -> SliderRowInput {
        SliderRowInput.from(widget: PreviewWidgetFactory.slider(
            label: label,
            value: value,
            minValue: minValue,
            maxValue: maxValue,
            step: step,
            icon: icon,
            switchSupport: switchSupport
        ))
    }
}

// MARK: - Previews

#Preview("Default Range (0-100)") {
    PreviewList {
        SliderRowView(
            input: SliderRowView.createPreviewInput(
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
            input: SliderRowView.createPreviewInput(
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
            input: SliderRowView.createPreviewInput(
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
            input: SliderRowView.createPreviewInput(
                label: "Brightness",
                value: 75
            ),
            fallbackSymbol: .sliderHorizontal3
        )
        SliderRowView(
            input: SliderRowView.createPreviewInput(
                label: "Temperature",
                value: 21,
                minValue: 16,
                maxValue: 28,
                step: 0.5
            ),
            fallbackSymbol: .thermometerMedium
        )
        SliderRowView(
            input: SliderRowView.createPreviewInput(
                label: "Volume",
                value: 30,
                minValue: 0,
                maxValue: 100,
                icon: "soundvolume"
            ),
            fallbackSymbol: .speakerWave2Fill
        )
        SliderRowView(
            input: SliderRowView.createPreviewInput(
                label: "Dimmer",
                value: 50,
                switchSupport: true
            ),
            fallbackSymbol: .lightbulbFill
        )
    }
}

#if DEBUG
#Preview("From PreviewConstants") {
    PreviewList {
        SliderRowView(
            input: SliderRowInput.from(widget: PreviewConstants.openHABSitemapPage!.widgets[3]),
            fallbackSymbol: .sliderHorizontal3
        )
    }
}
#endif
