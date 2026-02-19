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

import OpenHABCore
import SwiftUI

/// Transitional adapter: drives list from immutable row inputs while reusing existing widget-driven rows.
struct EmbeddingRowInputView: View {
    let rowInput: SitemapRowInput

    @EnvironmentObject var viewModel: SitemapPageViewModel

    private var regularRowInsets: EdgeInsets {
        EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)
    }

    private var regularRowBackground: Color {
        Color(UIColor.ohSecondarySystemGroupedBackground)
    }

    private var frameRowBackground: Color {
        Color(UIColor.ohSystemGroupedBackground)
    }

    var body: some View {
        switch rowInput {
        case let .frame(_, input):
            FrameRowInputView(input: input)
                .contentShape(Rectangle())
                .listRowInsets(frameRowInsets(input))
                .listRowBackground(frameRowBackground)
        case let .slider(rowID, input):
            SliderRowInputView(rowID: rowID, input: input)
                .contentShape(Rectangle())
                .listRowInsets(regularRowInsets)
                .listRowBackground(regularRowBackground)
        case let .selection(rowID, input):
            SelectionRowInputView(rowID: rowID, input: input)
                .contentShape(Rectangle())
                .listRowInsets(regularRowInsets)
                .listRowBackground(regularRowBackground)
        case let .segmented(rowID, input):
            SegmentedRowInputView(rowID: rowID, input: input)
                .contentShape(Rectangle())
                .listRowInsets(regularRowInsets)
                .listRowBackground(regularRowBackground)
        case let .setpoint(rowID, input):
            SetpointRowInputView(rowID: rowID, input: input)
                .contentShape(Rectangle())
                .listRowInsets(regularRowInsets)
                .listRowBackground(regularRowBackground)
        case let .text(rowID, input):
            TextRowInputView(rowID: rowID, input: input)
                .contentShape(Rectangle())
                .listRowInsets(regularRowInsets)
                .listRowBackground(regularRowBackground)
        case let .toggle(rowID, input):
            SwitchRowInputView(rowID: rowID, input: input)
                .contentShape(Rectangle())
                .listRowInsets(regularRowInsets)
                .listRowBackground(regularRowBackground)
        case let .rollershutter(rowID, input):
            RollershutterRowInputView(rowID: rowID, input: input)
                .contentShape(Rectangle())
                .listRowInsets(regularRowInsets)
                .listRowBackground(regularRowBackground)
        case let .input(rowID, input):
            InputRowInputView(rowID: rowID, input: input)
                .contentShape(Rectangle())
                .listRowInsets(regularRowInsets)
                .listRowBackground(regularRowBackground)
        case let .colorPicker(rowID, input):
            ColorPickerRowInputView(rowID: rowID, input: input)
                .contentShape(Rectangle())
                .listRowInsets(regularRowInsets)
                .listRowBackground(regularRowBackground)
        case let .media(rowID, input):
            MediaRowInputView(rowID: rowID, input: input)
                .contentShape(Rectangle())
                .listRowInsets(regularRowInsets)
                .listRowBackground(regularRowBackground)
        case let .colorTemperature(rowID, input):
            ColorTemperaturePickerRowInputView(rowID: rowID, input: input)
                .contentShape(Rectangle())
                .listRowInsets(regularRowInsets)
                .listRowBackground(regularRowBackground)
        case let .buttonGrid(rowID, input):
            ButtonGridRowInputView(rowID: rowID, input: input)
                .contentShape(Rectangle())
                .listRowInsets(regularRowInsets)
                .listRowBackground(regularRowBackground)
        case let .generic(rowID, input):
            if input.hasLinkedPage {
                Group {
                    if let widget = viewModel.widget(for: rowID) {
                        EmbeddingRowView(widget: widget)
                    } else {
                        EmptyView()
                    }
                }
            } else {
                GenericRowInputView(rowID: rowID, input: input)
                    .contentShape(Rectangle())
                    .listRowInsets(regularRowInsets)
                    .listRowBackground(regularRowBackground)
            }
        @unknown default:
            Group {
                if let widget = viewModel.widget(for: rowInput.rowID) {
                    EmbeddingRowView(widget: widget)
                } else {
                    EmptyView()
                }
            }
        }
    }

    private func frameRowInsets(_ input: FrameRowInput) -> EdgeInsets {
        let hasLabel = !input.displayState.labelText.isEmpty
        return hasLabel
            ? EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
            : EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
    }
}
