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

    @State private var optimisticCommand: String?
    @State private var optimisticBaseState: String?
    @State private var optimisticWidgetId: String?
    @State private var optimisticStartVersion: Int?

    var body: some View {
        let displayState = widget.displayState
        let mappings = displayState.mappings
        let widgetVersion = viewModel.widgetUpdateVersion(for: displayState.widgetId)
        let displayedCommand = effectiveCommand(displayState: displayState)
        ZStack {
            rowContent(displayState: displayState, displayedCommand: displayedCommand)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(nil, value: displayedCommand)

            Menu {
                ForEach(mappings.indices, id: \.self) { index in
                    let mapping = mappings[index]
                    let isSelected = displayedCommand == mapping.command
                    Button {
                        logger.info("Selection changed to: \(mapping.label)")
                        optimisticCommand = mapping.command
                        optimisticBaseState = displayState.effectiveState
                        optimisticWidgetId = displayState.widgetId
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
            .disabled(widget.readOnly ?? false)
        }
        .onAppear {
            clearOptimisticSelection()
        }
        .onChange(of: displayState.widgetId) { _ in
            clearOptimisticSelection()
        }
        .onChange(of: widgetVersion) { _ in
            guard let optimisticBaseState,
                  optimisticWidgetId == displayState.widgetId,
                  let optimisticStartVersion,
                  widgetVersion != optimisticStartVersion else { return }

            // Keep optimistic value while the server is still echoing the pre-command state.
            // Clear once the server state actually changed (to selected value or anything else).
            if displayState.effectiveState != optimisticBaseState {
                clearOptimisticSelection()
            } else {
                self.optimisticStartVersion = widgetVersion
            }
        }
    }

    @ViewBuilder
    private func rowContent(displayState: WidgetDisplayState, displayedCommand: String) -> some View {
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

            if let valueText = selectedValueText(displayState: displayState, displayedCommand: displayedCommand), !valueText.isEmpty {
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
