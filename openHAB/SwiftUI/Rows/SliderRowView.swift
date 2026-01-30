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
import SwiftUI

struct SliderRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @State private var sliderValue = 0.0
    @State private var isDragging = false

    @State private var updateTask: Task<Void, Never>?
    private let throttleInterval: TimeInterval = 0.9 // in seconds
    @EnvironmentObject var viewModel: SitemapPageViewModel

    @State private var lastSendTime: Date = .distantPast

    private var displayValue: Double {
        isDragging ? sliderValue : (widget.stateValueAsNumberState?.value ?? widget.minValue)
    }

    private var sliderRange: ClosedRange<Double> {
        widget.minValue ... widget.maxValue
    }

    var body: some View {
        HStack {
            Button {
                viewModel.sendCommand(widget.item, commandToSend: sliderValue <= widget.minValue ? "ON" : "OFF")
            } label: {
                HStack {
                    IconView(widget: widget)
                        .frame(width: 32, height: 32)

                    if let labelText = widget.labelText, !labelText.isEmpty {
                        Text(labelText)
                            .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
                    }

                    Spacer()

                    if let value = widget.labelValue {
                        Text(value)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!widget.switchSupport || (widget.readOnly ?? false))

            Slider(
                value: Binding(
                    get: { sliderValue },
                    set: { newValue in
                        sliderValue = newValue
                        if widget.shouldUseSliderUpdatesDuringMove() {
                            let now = Date()
                            if now.timeIntervalSince(lastSendTime) > 0.2 {
                                sendSliderUpdate(newValue)
                                lastSendTime = now
                            }
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
                lastSendTime = Date()
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
    .environmentObject(SitemapPageViewModel())
}
