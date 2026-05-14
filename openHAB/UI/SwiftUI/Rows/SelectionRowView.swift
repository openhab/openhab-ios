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

private struct SelectionRowContent: View {
    let input: SelectionRowInput
    let widgetVersion: Int
    let onSelect: (String) -> Void

    private let logger = Logger(subsystem: "org.openhab", category: "SelectionRowView")

    @State private var optimisticCommand: String?
    @State private var optimisticBaseState: String?
    @State private var optimisticWidgetId: String?
    @State private var optimisticStartVersion: Int?
    @State private var revertTask: Task<Void, Never>?

    var body: some View {
        let displayedCommand = effectiveCommand(displayState: input.displayState)
        ZStack {
            rowContent(displayedCommand: displayedCommand)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(nil, value: displayedCommand)
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
    private func rowContent(displayedCommand: String) -> some View {
        RowViewWithIcon(input: input) {
            if !input.displayState.labelText.isEmpty {
                let labelText = input.displayState.labelText
                Text(labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))
            }

            Spacer()

            // Make the entire trailing region (value + chevrons) the Menu label
            Menu {
                ForEach(input.mappings.indices, id: \.self) { index in
                    let mapping = input.mappings[index]
                    let isSelected = displayedCommand == mapping.command
                    Button {
                        logger.info("Selection changed to: \(mapping.label)")
                        withTransaction(Transaction(animation: nil)) {
                            optimisticCommand = mapping.command
                            optimisticBaseState = input.displayState.effectiveState
                            optimisticWidgetId = input.widgetId
                            optimisticStartVersion = widgetVersion
                        }
                        onSelect(mapping.command)
                        revertTask?.cancel()
                        revertTask = Task { @MainActor in
                            do { try await Task.sleep(for: .seconds(1)) } catch { return }
                            clearOptimisticSelection()
                        }
                    } label: {
                        if isSelected {
                            Label(mapping.label, systemSymbol: .checkmark)
                        } else {
                            Text(mapping.label)
                        }
                    }
                }
            } label: {
                ZStack {
                    // Make the entire remaining area after the row label tappable
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())

                    // Right-aligned visible content (value + chevrons)
                    HStack(spacing: 6) {
                        if let valueText = selectedValueText(displayState: input.displayState, displayedCommand: displayedCommand), !valueText.isEmpty {
                            Text(valueText)
                                .ohTextToken(.rowValue)
                                .foregroundStyle(input.valueColor.isEmpty ? .secondary : Color(fromString: input.valueColor))
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .layoutPriority(1)
                        }

                        Image(systemSymbol: .chevronUpChevronDown)
                            .ohTextToken(.secondary)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                // Improve layout stability during optimistic updates
                .layoutPriority(1)
                .id("value-\(displayedCommand)")
            }
            .buttonStyle(.plain)
            .disabled(input.readOnly)
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
        if let selectedLabel = mappedLabel(for: displayedCommand, mappings: input.mappings), !selectedLabel.isEmpty {
            return selectedLabel
        }
        return displayState.selectedLabel ?? displayState.labelValue
    }

    private func mappedLabel(for command: String, mappings: [OpenHABWidgetMapping]) -> String? {
        if let exact = mappings.first(where: { $0.command == command })?.label {
            return exact
        }

        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed = mappings.first(where: { $0.command.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedCommand })?.label {
            return trimmed
        }

        if let commandValue = Double(trimmedCommand) {
            if let numeric = mappings.first(where: {
                guard let mappingValue = Double($0.command.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
                return mappingValue == commandValue
            })?.label {
                return numeric
            }
        }

        return nil
    }

    private func clearOptimisticSelection() {
        revertTask?.cancel()
        revertTask = nil
        optimisticCommand = nil
        optimisticBaseState = nil
        optimisticWidgetId = nil
        optimisticStartVersion = nil
    }
}

struct SelectionRowView: View {
    let input: SelectionRowInput

    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        SelectionRowContent(
            input: input,
            widgetVersion: viewModel.widgetUpdateVersion(for: input.widgetId)
        ) { command in
            guard let itemName = input.itemName else { return }
            viewModel.sendCommand(command, for: itemName)
        }
    }
}
