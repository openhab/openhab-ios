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

    var body: some View {
        let displayState = widget.displayState
        ZStack {
            rowContent(displayState: displayState)
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
    private func rowContent(displayState: WidgetDisplayState) -> some View {
        HStack {
            IconView(widget: widget)
                .frame(width: 32, height: 32)

            if !displayState.labelText.isEmpty {
                let labelText = displayState.labelText
                Text(labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
            }

            Spacer()

            if let valueText = selectedValueText(displayState: displayState), !valueText.isEmpty {
                Text(valueText)
                    .ohTextToken(.rowValue)
                    .foregroundStyle(widget.valuecolor.isEmpty ? .secondary : Color(fromString: widget.valuecolor))
            }

            // Show disclosure indicator to indicate tappable selection
            Image(systemSymbol: .chevronUpChevronDown)
                .ohTextToken(.secondary)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    /// Returns the label of the currently selected mapping, or the widget's labelValue as fallback.
    private func selectedValueText(displayState: WidgetDisplayState) -> String? {
        displayState.selectedLabel ?? displayState.labelValue
    }
}
