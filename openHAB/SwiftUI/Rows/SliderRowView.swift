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

import OpenHABCore
import SwiftUI

struct SliderRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @State private var currentValue = 0.0
    @State private var isUserInteracting = false

    private var displayValue: Double {
        isUserInteracting ? currentValue : (widget.stateValueAsNumberState?.value ?? widget.minValue)
    }

    private var sliderRange: ClosedRange<Double> {
        widget.minValue ... widget.maxValue
    }

    var body: some View {
        HStack {
            IconView(widget: widget)
                .frame(width: 24, height: 24)

            Text(widget.labelText ?? "")

            Spacer()

            if let value = widget.labelValue {
                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Slider(value: $currentValue, in: sliderRange) { isEditing in
                isUserInteracting = isEditing
                if !isEditing {
                    sendSliderUpdate(currentValue)
                }
            }
        }
        .onAppear {
            loadCurrentValue()
        }
        .onChange(of: widget.stateValueAsNumberState?.value) { newValue in
            if !isUserInteracting, let newValue {
                currentValue = newValue
            }
        }
    }

    private func loadCurrentValue() {
        currentValue = widget.stateValueAsNumberState?.value ?? widget.minValue
    }

    private func sendSliderUpdate(_ newValue: Double) {
        var numberState = widget.stateValueAsNumberState
        numberState = numberState ?? NumberState(value: newValue)
        numberState?.value = newValue
        widget.sendItemUpdate(state: numberState)
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[3]
    VStack {
        SliderRowView(widget: widget)
        Spacer()
    }
}
