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
import os.log
import SFSafeSymbols
import SwiftUI

struct SelectionRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel

    private let logger = Logger(subsystem: "org.openhab", category: "SelectionRowView")

    private var mappings: [OpenHABWidgetMapping] {
        widget.mappingsOrItemOptions
    }

    private var displayState: WidgetDisplayState {
        widget.displayState
    }

    /// Returns the label of the currently selected mapping, or the widget's labelValue as fallback
    private var selectedValueText: String? {
        displayState.selectedLabel ?? displayState.labelValue
    }

    var body: some View {
        ZStack {
            rowContent
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(nil, value: displayState.effectiveState)

            Menu {
                ForEach(mappings.indices, id: \.self) { index in
                    let mapping = mappings[index]
                    let isSelected = displayState.effectiveState == mapping.command
                    Button {
                        logger.info("Selection changed to: \(mapping.label)")
                        viewModel.sendCommand(mapping.command, for: widget)
                    } label: {
                        if isSelected {
                            Label(mapping.label, systemSymbol: .checkmark)
                        } else {
                            Text(mapping.label)
                        }
                    }
                }
            } label: {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(widget.readOnly ?? false)
        }
    }

    @ViewBuilder
    private var rowContent: some View {
        HStack {
            IconView(widget: widget)
                .frame(width: 32, height: 32)

            if !displayState.labelText.isEmpty {
                let labelText = displayState.labelText
                Text(labelText)
                    .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
                    .lineLimit(1)
            }

            Spacer()

            if let valueText = selectedValueText, !valueText.isEmpty {
                Text(valueText)
                    .foregroundStyle(widget.valuecolor.isEmpty ? .secondary : Color(fromString: widget.valuecolor))
                    .lineLimit(1)
            }

            // Show disclosure indicator to indicate tappable selection
            Image(systemSymbol: .chevronUpChevronDown)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}
