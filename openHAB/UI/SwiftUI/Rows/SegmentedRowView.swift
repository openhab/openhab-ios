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
import Flow
import OpenHABCore
import os.log
import SFSafeSymbols
import SwiftUI

// MARK: - Button-area width alignment

private struct SegmentedButtonAreaWidthKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct AlignSegmentedButtonAreasModifier: ViewModifier {
    @State private var maxWidth: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(SegmentedButtonAreaWidthKey.self) { maxWidth = $0 }
            .environment(\.segmentedButtonAreaMaxWidth, maxWidth)
    }
}

private struct ButtonAreaWidthModifier: ViewModifier {
    @Environment(\.segmentedButtonAreaMaxWidth) private var maxWidth

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: SegmentedButtonAreaWidthKey.self, value: geo.size.width)
                }
            )
            .frame(width: maxWidth > 0 ? maxWidth : nil, alignment: .trailing)
    }
}

// MARK: -

private struct SegmentedRowContent: View {
    let input: SegmentedRowInput
    let widgetVersion: Int
    let interactionState: RowInteractionState
    let fallbackSymbol: SFSymbol?
    let sendCommand: (String, WidgetCommandPolicy, WidgetCommandPhase) -> Void

    @Environment(\.colorScheme) var colorScheme

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetSegmentedView")
    @State private var optimisticSelectedIndex: Int?
    @State private var optimisticBaseState: String?
    @State private var optimisticWidgetId: String?
    @State private var optimisticStartVersion: Int?
    @State private var revertTask: Task<Void, Never>?
    @State private var pressedIndex: Int?
    @State private var singlePressed = false
    @State private var triggerSelectionFeedback = false
    @State private var triggerPressFeedback = false

    var body: some View {
        let selectedIndex = effectiveSelectedIndex(displayState: input.displayState, mappings: input.mappings)
        RowViewWithIcon(input: input, fallbackSymbol: fallbackSymbol, spacing: 0) {
            if !input.displayState.labelText.isEmpty {
                let labelText = input.displayState.labelText
                Text(labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))
                    .padding(.leading, 8)
                    .layoutPriority(1)
            }

            if let detailTextLabel = input.displayState.labelValue, !detailTextLabel.isEmpty {
                Spacer(minLength: 8)
                Text(detailTextLabel)
                    .ohTextToken(.rowValue)
                    .foregroundStyle(input.valueColor.isEmpty ? Color(.secondaryLabel) : Color(fromString: input.valueColor))
                    .layoutPriority(1)
                    .monospacedDigit()
            }

            if !input.mappings.isEmpty {
                let noInputLabelValue = input.displayState.labelValue.isNilOrEmpty
                if input.displayState.hasPressReleaseMappings {
                    // Press-release buttons for mappings with releaseCommand
                    if !(input.displayState.labelValue?.isEmpty == false) {
                        Spacer(minLength: 8)
                    }
                    pressReleaseButtons(mappings: input.mappings)
                        .buttonAreaWidth()
                        .padding(.leading, 8)

                } else if input.mappings.count == 1 {
                    if noInputLabelValue {
                        Spacer(minLength: 8)
                    }
                    singleMappingButton(displayState: input.displayState, mappings: input.mappings, widgetVersion: widgetVersion)
                        .buttonAreaWidth()
                        .padding(.leading, 8)
                } else {
                    if noInputLabelValue {
                        Spacer(minLength: 8)
                    }
                    let leadingPadding: CGFloat = noInputLabelValue ? 0 : 8
                    // Button-based segmented control with animated selection indicator
                    segmentedButtons(mappings: input.mappings, selectedIndex: selectedIndex, displayState: input.displayState, widgetVersion: widgetVersion)
                        .frame(minWidth: 75)
                        .buttonAreaWidth()
                        .padding(.leading, leadingPadding)
                        .layoutPriority(1)
                }
            }
        }
        .onAppear {
            clearOptimisticSelection()
        }
        .onChange(of: input.widgetId) {
            clearOptimisticSelection()
        }
        .onChange(of: widgetVersion) {
            guard let optimisticBaseState,
                  optimisticWidgetId == input.widgetId,
                  let optimisticStartVersion,
                  widgetVersion != optimisticStartVersion else { return }

            // Keep optimistic selection while server still echoes pre-command state.
            // Clear once the server state changed.
            if input.displayState.effectiveState != optimisticBaseState {
                clearOptimisticSelection()
            } else {
                self.optimisticStartVersion = widgetVersion
            }
        }
        .onChange(of: interactionState) { _, newState in
            switch newState {
            case .idle:
                // HTTP command completed. Wait for SSE/long-poll to deliver the new state.
                // Items with autoupdate=false never trigger the widgetVersion path above,
                // so this timer is their only revert.
                guard optimisticWidgetId != nil else { return }
                revertTask?.cancel()
                revertTask = Task { @MainActor in
                    do { try await Task.sleep(for: .seconds(1.5)) } catch { return }
                    clearOptimisticSelection()
                }
            case .failed:
                clearOptimisticSelection()
            case .sending, .queued, .offline:
                break
            }
        }
        .sensorySelectionFeedbackIfAvailable(trigger: triggerSelectionFeedback)
        .sensoryHeavyFeedbackIfAvailable(trigger: triggerPressFeedback)
    }

    /// Button-based segmented control with animated selection indicator
    private func segmentedButtons(mappings: [OpenHABWidgetMapping],
                                  selectedIndex: Int?,
                                  displayState: WidgetDisplayState,
                                  widgetVersion: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(0 ..< mappings.count, id: \.self) { index in
                segmentButton(
                    at: index,
                    mappings: mappings,
                    displayState: displayState,
                    widgetVersion: widgetVersion
                )
            }
        }
        .background(
            GeometryReader { geometry in
                // Layer 1: Dark gray background
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(uiColor: colorScheme == .dark ? .systemGray4 : .systemGray5))
                // Layer 2: Selection indicator (lighter, more visible)
                if let selectedIndex, !mappings.isEmpty {
                    let segmentWidth = geometry.size.width / CGFloat(mappings.count)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            colorScheme == .dark
                                ? Color(uiColor: .systemGray2)
                                : Color(uiColor: .systemBackground)
                        )
                        .frame(width: segmentWidth - 4, height: geometry.size.height - 4)
                        .offset(x: CGFloat(selectedIndex) * segmentWidth + 2, y: 2)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedIndex)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    private func pressReleaseButtons(mappings: [OpenHABWidgetMapping]) -> some View {
        HStack(spacing: 8) {
            ForEach(mappings.indices, id: \.self) { index in
                pressReleaseButton(for: mappings[index], at: index)
            }
        }
    }

    /// Whether the single mapping button is selected (item state matches the mapping command)
    private func isSingleMappingSelected(displayState: WidgetDisplayState, mappings: [OpenHABWidgetMapping]) -> Bool {
        guard let mapping = mappings.first else { return false }
        let selected = effectiveSelectedIndex(displayState: displayState, mappings: mappings)
        guard let selected else { return false }
        return mappings.indices.contains(selected) && mappings[selected].command == mapping.command
    }

    @ViewBuilder
    private func singleMappingButton(displayState: WidgetDisplayState, mappings: [OpenHABWidgetMapping], widgetVersion: Int) -> some View {
        let mapping = mappings[0]
        let isSelected = isSingleMappingSelected(displayState: displayState, mappings: mappings)

        Text(mapping.label)
            .ohTextToken(.control)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(minWidth: 50)
            .foregroundStyle(.primary)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(
                        isSelected
                            ? Color(uiColor: colorScheme == .dark ? .systemGray2 : .systemBackground)
                            : Color(uiColor: colorScheme == .dark ? .systemGray4 : .systemGray5)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        (isSelected ? Color.secondary.opacity(0.8) : Color.secondary.opacity(0.3)),
                        lineWidth: 0.5
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if !isSelected {
                    // Toggle ON
                    triggerSelectionFeedback.toggle()
                    startOptimisticSelection(
                        command: mapping.command,
                        displayState: displayState,
                        mappings: mappings,
                        widgetVersion: widgetVersion
                    )
                    logger.info("Single mapping toggle ON, command: \(mapping.command)")
                    sendCommand(mapping.command, .immediate, .change)
                } else {
                    // Toggle OFF
                    let offCommand: String = {
                        if let rc = mapping.releaseCommand, !rc.isEmpty { return rc }
                        // Default to OFF if no explicit releaseCommand is provided
                        return "OFF"
                    }()
                    triggerSelectionFeedback.toggle()
                    // Clear optimistic selection to reflect OFF state locally until server echoes
                    optimisticSelectedIndex = nil
                    optimisticBaseState = displayState.effectiveState
                    optimisticWidgetId = displayState.widgetId
                    optimisticStartVersion = widgetVersion
                    revertTask?.cancel()
                    revertTask = nil
                    logger.info("Single mapping toggle OFF, command: \(offCommand)")
                    sendCommand(offCommand, .immediate, .change)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    // MARK: - Helper Methods

    private func selectedIndex(for state: String, mappings: [OpenHABWidgetMapping]) -> Int? {
        mappings.firstIndex { $0.command == state }
    }

    private func effectiveSelectedIndex(displayState: WidgetDisplayState, mappings: [OpenHABWidgetMapping]) -> Int? {
        if optimisticWidgetId == displayState.widgetId, let optimisticSelectedIndex {
            return optimisticSelectedIndex
        }
        return selectedIndex(for: displayState.effectiveState, mappings: mappings)
    }

    @ViewBuilder
    private func segmentButton(at index: Int,
                               mappings: [OpenHABWidgetMapping],
                               displayState: WidgetDisplayState,
                               widgetVersion: Int) -> some View {
        let mapping = mappings[index]

        Button {
            logger.info("Segment tapped: \(index), command: \(mapping.command)")
            startOptimisticSelection(
                command: mapping.command,
                displayState: displayState,
                mappings: mappings,
                widgetVersion: widgetVersion
            )
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                optimisticSelectedIndex = index
            }
            triggerSelectionFeedback.toggle()
            sendCommand(mapping.command, .immediate, .change)
        } label: {
            Text(mapping.label)
                .ohTextToken(.control)
                .bold()
                .padding(.vertical, 5)
                .frame(minWidth: 30, maxWidth: 120)
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func pressReleaseButton(for mapping: OpenHABWidgetMapping, at index: Int) -> some View {
        let isPressed = pressedIndex == index
        Text(mapping.label)
            .ohTextToken(.control)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(minWidth: 50)
            .foregroundStyle(.primary)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(
                        isPressed
                            ? Color(uiColor: colorScheme == .dark ? .systemGray2 : .systemBackground)
                            : Color(uiColor: colorScheme == .dark ? .systemGray4 : .systemGray5)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if pressedIndex != index {
                            pressedIndex = index
                            triggerPressFeedback.toggle()
                            // Send command on press
                            logger.info("Sending press command: \(mapping.command)")
                            sendCommand(
                                mapping.command,
                                .pressRelease,
                                .press
                            )
                        }
                    }
                    .onEnded { _ in
                        pressedIndex = nil
                        if let releaseCommand = mapping.releaseCommand, !releaseCommand.isEmpty {
                            triggerPressFeedback.toggle()
                            logger.info("Sending release command: \(releaseCommand)")
                            sendCommand(
                                releaseCommand,
                                .pressRelease,
                                .release
                            )
                        }
                    }
            )
    }

    private func startOptimisticSelection(command: String,
                                          displayState: WidgetDisplayState,
                                          mappings: [OpenHABWidgetMapping],
                                          widgetVersion: Int) {
        optimisticSelectedIndex = selectedIndex(for: command, mappings: mappings)
        optimisticBaseState = displayState.effectiveState
        optimisticWidgetId = displayState.widgetId
        optimisticStartVersion = widgetVersion
        revertTask?.cancel()
        revertTask = nil
        // Revert is driven by interactionState transitions (see onChange), not a tap-time timer.
    }

    private func clearOptimisticSelection() {
        revertTask?.cancel()
        revertTask = nil
        optimisticSelectedIndex = nil
        optimisticBaseState = nil
        optimisticWidgetId = nil
        optimisticStartVersion = nil
    }
}

// swiftlint:disable:next file_types_order
struct SegmentedRowView: View {
    let input: SegmentedRowInput
    var fallbackSymbol: SFSymbol?

    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        SegmentedRowContent(
            input: input,
            widgetVersion: viewModel.widgetUpdateVersion(for: input.widgetId),
            interactionState: viewModel.rowInteractionState(for: input.itemName),
            fallbackSymbol: fallbackSymbol
        ) { command, policy, phase in
            guard let itemName = input.itemName else { return }
            viewModel.sendCommand(command, for: itemName, policy: policy, phase: phase)
        }
    }
}

// MARK: - Preview Helpers

/// Wrapper for consistent preview list styling matching SitemapPageView
struct PreviewList<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        List {
            content()
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
        .alignSegmentedButtonAreas()
        .listStyle(.plain)
        .listRowSpacing(0)
        .environment(\.defaultMinListRowHeight, 32)
        .environmentObject(SitemapPageViewModel())
    }
}

private extension SegmentedRowView {
    static func createPreviewInput(label: String,
                                   detailLabel: String? = nil,
                                   icon: String = "switch",
                                   mappings: [OpenHABWidgetMapping],
                                   selectedState: String? = nil) -> SegmentedRowInput {
        SegmentedRowInput.from(widget: PreviewWidgetFactory.segmented(
            label: label,
            mappings: mappings,
            selectedState: selectedState,
            icon: icon,
            valueText: detailLabel
        ))
    }
}

extension EnvironmentValues {
    @Entry var segmentedButtonAreaMaxWidth: CGFloat = 0
}

extension View {
    func alignSegmentedButtonAreas() -> some View {
        modifier(AlignSegmentedButtonAreasModifier())
    }
}

private extension View {
    func buttonAreaWidth() -> some View {
        modifier(ButtonAreaWidthModifier())
    }
}

// MARK: - Previews

#Preview("Short Labels") {
    PreviewList {
        SegmentedRowView(
            input: SegmentedRowView.createPreviewInput(
                label: "Light Switch",
                detailLabel: "1",
                mappings: [
                    OpenHABWidgetMapping(command: "ON", label: "ON"),
                    OpenHABWidgetMapping(command: "OFF", label: "OFF")
                ],
                selectedState: "ON"
            )
        )
    }
}

#Preview("Charts Period") {
    PreviewList {
        SegmentedRowView(
            input: SegmentedRowView.createPreviewInput(
                label: "Charts Period",
                mappings: [
                    OpenHABWidgetMapping(command: "D", label: "Day"),
                    OpenHABWidgetMapping(command: "W", label: "Week"),
                    OpenHABWidgetMapping(command: "M", label: "M"),
                    OpenHABWidgetMapping(command: "4h", label: "4h")
                ],
                selectedState: "D"
            )
        )
    }
}

#Preview("Long Labels") {
    PreviewList {
        SegmentedRowView(
            input: SegmentedRowView.createPreviewInput(
                label: "Temperature Control",
                detailLabel: "3",
                mappings: [
                    OpenHABWidgetMapping(command: "manual", label: "Manual"),
                    OpenHABWidgetMapping(command: "calendar", label: "Calendar"),
                    OpenHABWidgetMapping(command: "automatic", label: "Automatic")
                ],
                selectedState: "automatic"
            )
        )
    }
}

#Preview("Multiple Segments (4)") {
    PreviewList {
        SegmentedRowView(
            input: SegmentedRowView.createPreviewInput(
                label: "Fan Speed",
                detailLabel: "4",
                mappings: [
                    OpenHABWidgetMapping(command: "0", label: "Off"),
                    OpenHABWidgetMapping(command: "1", label: "Low"),
                    OpenHABWidgetMapping(command: "2", label: "Med"),
                    OpenHABWidgetMapping(command: "3", label: "High")
                ],
                selectedState: "3"
            )
        )
    }
}

#Preview("PressRelease") {
    PreviewList {
        SegmentedRowView(
            input: SegmentedRowView.createPreviewInput(
                label: "All Shutters",
                detailLabel: "NA",
                mappings: [
                    OpenHABWidgetMapping(command: "DOWN", label: "DOWN", releaseCommand: "OFF")
                ],
                selectedState: "DOWN"
            )
        )
    }
}

#Preview("Single Mapping") {
    PreviewList {
        SegmentedRowView(
            input: SegmentedRowView.createPreviewInput(
                label: "Scene",
                mappings: [
                    OpenHABWidgetMapping(command: "RUN", label: "Run")
                ],
                selectedState: "RUN"
            )
        )
    }
}

#Preview("All Scenarios") {
    PreviewList {
        SegmentedRowView(
            input: SegmentedRowView.createPreviewInput(
                label: "Light",
                detailLabel: "1",
                mappings: [
                    OpenHABWidgetMapping(command: "ON", label: "ON"),
                    OpenHABWidgetMapping(command: "OFF", label: "OFF")
                ],
                selectedState: "ON"
            )
        )
        SegmentedRowView(
            input: SegmentedRowView.createPreviewInput(
                label: "Climate Mode",
                detailLabel: "2",
                mappings: [
                    OpenHABWidgetMapping(command: "m", label: "Manual"),
                    OpenHABWidgetMapping(command: "a", label: "Auto"),
                    OpenHABWidgetMapping(command: "s", label: "Schedule")
                ],
                selectedState: "a"
            )
        )
        SegmentedRowView(
            input: SegmentedRowView.createPreviewInput(
                label: "Fan Speed",
                detailLabel: "2",
                mappings: [
                    OpenHABWidgetMapping(command: "0", label: "Off"),
                    OpenHABWidgetMapping(command: "1", label: "Low"),
                    OpenHABWidgetMapping(command: "2", label: "Med"),
                    OpenHABWidgetMapping(command: "3", label: "High")
                ],
                selectedState: "2"
            )
        )
        SegmentedRowView(
            input: SegmentedRowView.createPreviewInput(
                label: "Charts Period",
                mappings: [
                    OpenHABWidgetMapping(command: "D", label: "Day"),
                    OpenHABWidgetMapping(command: "W", label: "Week"),
                    OpenHABWidgetMapping(command: "M", label: "M"),
                    OpenHABWidgetMapping(command: "4h", label: "4h")
                ],
                selectedState: "D"
            )
        )
        SegmentedRowView(
            input: SegmentedRowView.createPreviewInput(
                label: "All Shutters",
                detailLabel: "NA",
                mappings: [
                    OpenHABWidgetMapping(command: "DOWN", label: "DOWN", releaseCommand: "OFF"),
                    OpenHABWidgetMapping(command: "UP", label: " UP ", releaseCommand: "OFF")

                ],
                selectedState: "DOWN"
            )
        )

        SegmentedRowView(
            input: SegmentedRowView.createPreviewInput(
                label: "Office Shutter",
                detailLabel: "NA",
                mappings: [
                    OpenHABWidgetMapping(command: "DOWN", label: "DOWN", releaseCommand: "OFF"),
                    OpenHABWidgetMapping(command: "UP", label: "UP", releaseCommand: "OFF")
                ],
                selectedState: "DOWN"
            )
        )

        SegmentedRowView(
            input: SegmentedRowView.createPreviewInput(
                label: "Scene",
                mappings: [
                    OpenHABWidgetMapping(command: "RUN", label: "DOWN")
                ],
                selectedState: "DOWN"
            )
        )
    }
}

#if DEBUG
#Preview("From PreviewConstants") {
    PreviewList {
        SegmentedRowView(
            input: SegmentedRowInput.from(widget: PreviewConstants.openHABSitemapPage!.widgets[4])
        )
    }
}
#endif
