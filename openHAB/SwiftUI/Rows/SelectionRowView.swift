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

private struct SelectionRowInput {
    let displayState: WidgetDisplayState
    let mappings: [OpenHABWidgetMapping]
    let labelColor: String
    let valueColor: String
    let readOnly: Bool
    let widgetId: String

    static func from(widget: OpenHABWidget) -> SelectionRowInput {
        let displayState = widget.displayState
        return SelectionRowInput(
            displayState: displayState,
            mappings: displayState.mappings,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            readOnly: widget.readOnly ?? false,
            widgetId: displayState.widgetId
        )
    }
}

struct SelectionRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel

    private let logger = Logger(subsystem: "org.openhab", category: "SelectionRowView")

    @State private var optimisticCommand: String?
    @State private var optimisticBaseState: String?
    @State private var optimisticWidgetId: String?
    @State private var optimisticStartVersion: Int?

    var body: some View {
        let input = SelectionRowInput.from(widget: widget)
        let widgetVersion = viewModel.widgetUpdateVersion(for: input.widgetId)
        let displayedCommand = effectiveCommand(displayState: input.displayState)
        ZStack {
            rowContent(input: input, displayedCommand: displayedCommand)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(nil, value: displayedCommand)

            Menu {
                ForEach(input.mappings.indices, id: \.self) { index in
                    let mapping = input.mappings[index]
                    let isSelected = displayedCommand == mapping.command
                    Button {
                        logger.info("Selection changed to: \(mapping.label)")
                        optimisticCommand = mapping.command
                        optimisticBaseState = input.displayState.effectiveState
                        optimisticWidgetId = input.widgetId
                        optimisticStartVersion = widgetVersion
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
            .disabled(input.readOnly)
        }
        .onAppear {
            clearOptimisticSelection()
        }
        .onChange(of: input.widgetId) { _ in
            clearOptimisticSelection()
        }
        .onChange(of: widgetVersion) { _ in
            guard let optimisticBaseState,
                  optimisticWidgetId == input.widgetId,
                  let optimisticStartVersion,
                  widgetVersion != optimisticStartVersion else { return }

            // Keep optimistic value while the server is still echoing the pre-command state.
            // Clear once the server state actually changed (to selected value or anything else).
            if input.displayState.effectiveState != optimisticBaseState {
                clearOptimisticSelection()
            } else {
                self.optimisticStartVersion = widgetVersion
            }
        }
    }

    @ViewBuilder
    private func rowContent(input: SelectionRowInput, displayedCommand: String) -> some View {
        HStack {
            IconView(widget: widget)
                .frame(width: 32, height: 32)

            if !input.displayState.labelText.isEmpty {
                let labelText = input.displayState.labelText
                Text(labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))
            }

            Spacer()

            if let valueText = selectedValueText(displayState: input.displayState, displayedCommand: displayedCommand), !valueText.isEmpty {
                Text(valueText)
                    .ohTextToken(.rowValue)
                    .foregroundStyle(input.valueColor.isEmpty ? .secondary : Color(fromString: input.valueColor))
            }

            // Show disclosure indicator to indicate tappable selection
            Image(systemSymbol: .chevronUpChevronDown)
                .ohTextToken(.secondary)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    private func effectiveCommand(displayState: WidgetDisplayState) -> String {
        if optimisticWidgetId == displayState.widgetId, let optimisticCommand {
            return optimisticCommand
        }
        return displayState.effectiveState
    }

    /// Returns the label of the currently selected mapping, or the widget's labelValue as fallback.
    private func selectedValueText(displayState: WidgetDisplayState, displayedCommand: String) -> String? {
        if let selectedLabel = displayState.mappings.first(where: { $0.command == displayedCommand })?.label, !selectedLabel.isEmpty {
            return selectedLabel
        }
        return displayState.selectedLabel ?? displayState.labelValue
    }

    private func clearOptimisticSelection() {
        optimisticCommand = nil
        optimisticBaseState = nil
        optimisticWidgetId = nil
        optimisticStartVersion = nil
    }
}
