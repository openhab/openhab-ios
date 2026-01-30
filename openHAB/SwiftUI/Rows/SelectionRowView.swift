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

struct SelectionRowView: View {
    @ObservedObject var widget: OpenHABWidget

    private var mappings: [OpenHABWidgetMapping] {
        widget.mappingsOrItemOptions
    }

    /// Returns the label of the currently selected mapping, or the widget's labelValue as fallback
    private var selectedValueText: String? {
        if let state = widget.item?.state,
           let selectedMapping = mappings.first(where: { $0.command == state }) {
            return selectedMapping.label
        }
        return widget.labelValue
    }

    var body: some View {
        HStack {
            IconView(widget: widget)
                .frame(width: 32, height: 32)

            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
            }

            Spacer()

            if let valueText = selectedValueText, !valueText.isEmpty {
                Text(valueText)
                    .foregroundStyle(widget.valuecolor.isEmpty ? .secondary : Color(fromString: widget.valuecolor))
            }

            // Show disclosure indicator to indicate tappable selection
            Image(systemSymbol: .chevronUpChevronDown)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
