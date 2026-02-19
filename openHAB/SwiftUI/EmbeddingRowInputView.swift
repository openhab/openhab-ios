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

    var body: some View {
        switch rowInput {
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
        default:
            Group {
                if let widget = viewModel.widget(for: rowInput.rowID) {
                    EmbeddingRowView(widget: widget)
                } else {
                    EmptyView()
                }
            }
        }
    }
}
