// Copyright (c) 2010-2025 Contributors to the openHAB project
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
import SwiftUI

struct SliderRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @State private var sliderValue = 0.0
    @State private var isDragging = false

    @State private var updateTask: Task<Void, Never>?
    @State private var lastSentTime = Date.distantPast
    private let throttleInterval: TimeInterval = 0.9 // in seconds
    @EnvironmentObject var viewModel: SitemapPageViewModel

    private var displayValue: Double {
        isDragging ? sliderValue : (widget.stateValueAsNumberState?.value ?? widget.minValue)
    }

    private var sliderRange: ClosedRange<Double> {
        widget.minValue ... widget.maxValue
    }

    var body: some View {
        HStack {
            HStack {
                IconView(widget: widget)
                    .frame(width: 24, height: 24)

                if let labelText = widget.labelText, !labelText.isEmpty {
                    Text(labelText)
                        .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
                }

                Spacer()

                if let value = widget.labelValue {
                    Text(value)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle()) // 🔍 Make row but not slider tappable
            .onTapGesture {
                if widget.switchSupport, !(widget.readOnly ?? false) {
                    viewModel.sendCommand(widget.item, commandToSend: sliderValue <= widget.minValue ? "ON" : "OFF")
                }
            }

            Slider(
                value: Binding(
                    get: { sliderValue },
                    set: { newValue in
                        sliderValue = newValue
                        if widget.shouldUseSliderUpdatesDuringMove() {
                            sendSliderUpdate(newValue)
                        }
                    }
                ),
                in: sliderRange
            ) { editing in
                isDragging = editing
                if !editing, !widget.shouldUseSliderUpdatesDuringMove() {
                    sendSliderUpdate(sliderValue)
                }
            }
            .disabled(widget.readOnly ?? false)
        }
        .onAppear {
            loadCurrentValue()
        }
        .onChange(of: widget.stateValueAsNumberState?.value) { newValue in
            if !isDragging, let newValue {
                sliderValue = newValue
            }
        }
        .onDisappear {
            updateTask?.cancel()
        }
    }

    private func loadCurrentValue() {
        sliderValue = widget.stateValueAsNumberState?.value ?? widget.minValue
    }

    private func sendSliderUpdate(_ newValue: Double) {
        var numberState = widget.stateValueAsNumberState
        numberState = numberState ?? NumberState(value: newValue)
        numberState?.value = newValue
        viewModel.sendToUpdate(item: widget.item, state: numberState)
    }

    private func throttledSendSliderUpdate(_ newValue: Double) {
        updateTask?.cancel()

        updateTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(throttleInterval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                sendSliderUpdate(sliderValue)
                lastSentTime = Date()
            }
        }
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[3]
    VStack {
        SliderRowView(widget: widget)
        Spacer()
    }
}
