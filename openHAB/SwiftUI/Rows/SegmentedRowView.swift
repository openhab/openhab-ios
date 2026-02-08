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

// swiftlint:disable:next file_types_order
struct SegmentedRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel
    @Environment(\.colorScheme) var colorScheme

    /// Optional SF Symbol fallback for IconView (useful for previews)
    var fallbackSymbol: SFSymbol?

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetSegmentedView")

    private var mappings: [OpenHABWidgetMapping] {
        widget.mappingsOrItemOptions
    }

    @State private var selectedIndex: Int?
    @State private var pressedIndex: Int?
    @State private var singlePressed = false

    var body: some View {
        HStack(spacing: 0) {
            IconView(widget: widget, fallbackSymbol: fallbackSymbol)
                .frame(width: 32, height: 32)

            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 8)
                    .layoutPriority(1)
            }

            if let detailTextLabel = widget.labelValue, !detailTextLabel.isEmpty {
                Spacer(minLength: 8)
                Text(detailTextLabel)
                    .foregroundStyle(widget.valuecolor.isEmpty ? Color(uiColor: UIColor.ohSecondaryLabel) : Color(fromString: widget.valuecolor))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
            }

            if !mappings.isEmpty {
                if widget.hasPressReleaseMappings {
                    // Press-release buttons for mappings with releaseCommand
                    if !(widget.labelValue?.isEmpty == false) {
                        Spacer(minLength: 8)
                    }
                    pressReleaseButtons
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.leading, 8)

                } else if mappings.count == 1 {
                    if widget.labelValue.isNilOrEmpty {
                        Spacer(minLength: 8)
                    }
                    singleMappingButton
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.leading, 8)
                } else {
                    // Button-based segmented control with animated selection indicator
                    segmentedButtons
                        .frame(minWidth: 75)
                        .padding(.leading, 8)
                        .layoutPriority(1)
                }
            }
        }
        .onAppear {
            selectedIndex = widget.mapCommandtoIndex(with: widget.item?.state)
        }
        .onChange(of: widget.item?.state) { newState in
            selectedIndex = widget.mapCommandtoIndex(with: newState)
        }
    }

    /// Button-based segmented control with animated selection indicator
    @ViewBuilder
    private var segmentedButtons: some View {
        HStack(spacing: 0) {
            ForEach(0 ..< mappings.count, id: \.self) { index in
                segmentButton(at: index)
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

    @ViewBuilder
    private var pressReleaseButtons: some View {
        HStack(spacing: 8) {
            ForEach(mappings.indices, id: \.self) { index in
                pressReleaseButton(for: mappings[index], at: index)
            }
        }
    }

    /// Whether the single mapping button is selected (item state matches the mapping command)
    private var isSingleMappingSelected: Bool {
        guard let state = widget.item?.state else { return false }
        return state == mappings[0].command
    }

    @ViewBuilder
    private var singleMappingButton: some View {
        let mapping = mappings[0]
        let isSelected = isSingleMappingSelected

        Text(mapping.label)
            .font(.footnote)
            .bold()
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(minWidth: 50)
            .foregroundStyle(.primary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        (singlePressed || isSelected)
                            ? (colorScheme == .dark ? Color(uiColor: .systemGray2) : Color(uiColor: .systemBackground))
                            : Color.clear
                    )
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if singlePressed == false {
                            singlePressed = true
                            logger.info("Segment mapping pressed, command: \(mapping.command)")
                            viewModel.sendCommand(widget.item, commandToSend: mapping.command)
                        }
                    }
                    .onEnded { _ in
                        singlePressed = false
                    }
            )
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(uiColor: colorScheme == .dark ? .systemGray4 : .systemGray5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .animation(.easeInOut(duration: 0.1), value: singlePressed)
    }

    // MARK: - Helper Methods

    @ViewBuilder
    private func segmentButton(at index: Int) -> some View {
        let mapping = mappings[index]

        Button {
            logger.info("Segment tapped: \(index), command: \(mapping.command)")
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedIndex = index
            }
            viewModel.sendCommand(widget.item, commandToSend: mapping.command)
        } label: {
            Text(mapping.label)
                .font(.footnote)
                .bold()
                .lineLimit(1)
                .truncationMode(.tail)
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
            .font(.footnote)
            .bold()
            .lineLimit(1)
            .truncationMode(.tail)
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
                            // Send command on press
                            logger.info("Sending press command: \(mapping.command)")
                            viewModel.sendCommand(widget.item, commandToSend: mapping.command)
                        }
                    }
                    .onEnded { _ in
                        pressedIndex = nil
                        // Send release command on release
                        if let releaseCommand = mapping.releaseCommand, !releaseCommand.isEmpty {
                            logger.info("Sending release command: \(releaseCommand)")
                            viewModel.sendCommand(widget.item, commandToSend: releaseCommand)
                        }
                    }
            )
    }
}

// MARK: - Preview Helpers

#if DEBUG
/// Wrapper for consistent preview list styling matching SitemapPageView
struct PreviewList<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        List {
            content()
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
        .listStyle(.plain)
        .listRowSpacing(0)
        .environment(\.defaultMinListRowHeight, 32)
        .environmentObject(SitemapPageViewModel())
    }
}

private extension SegmentedRowView {
    static func createPreviewWidget(label: String,
                                    detailLabel: String? = nil,
                                    icon: String = "switch",
                                    mappings: [OpenHABWidgetMapping],
                                    selectedState: String? = nil) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = UUID().uuidString
        if let detailLabel, !detailLabel.isEmpty {
            widget.label = "\(label) [\(detailLabel)]"
        } else {
            widget.label = label
        }
        widget.type = .switchWidget
        widget.icon = icon
        widget.mappings = mappings

        let item = OpenHABItem(
            name: "Preview_\(label.replacingOccurrences(of: " ", with: "_"))",
            type: "String",
            state: selectedState ?? mappings.first?.command ?? "",
            link: "",
            label: detailLabel ?? label,
            groupType: nil,
            stateDescription: nil,
            commandDescription: nil,
            members: [],
            category: nil,
            options: nil
        )
        widget.item = item

        return widget
    }
}
#endif

// MARK: - Previews

#Preview("Short Labels") {
    PreviewList {
        SegmentedRowView(
            widget: SegmentedRowView.createPreviewWidget(
                label: "Light Switch",
                detailLabel: "1",
                mappings: [
                    OpenHABWidgetMapping(command: "ON", label: "ON"),
                    OpenHABWidgetMapping(command: "OFF", label: "OFF")
                ],
                selectedState: "ON"
            ),
            fallbackSymbol: .switch2
        )
    }
}

#Preview("Charts Period") {
    PreviewList {
        SegmentedRowView(
            widget: SegmentedRowView.createPreviewWidget(
                label: "Charts Period",
                mappings: [
                    OpenHABWidgetMapping(command: "D", label: "Day"),
                    OpenHABWidgetMapping(command: "W", label: "Week"),
                    OpenHABWidgetMapping(command: "M", label: "M"),
                    OpenHABWidgetMapping(command: "4h", label: "4h")
                ],
                selectedState: "D"
            ),
            fallbackSymbol: .chartBarFill
        )
    }
}

#Preview("Long Labels") {
    PreviewList {
        SegmentedRowView(
            widget: SegmentedRowView.createPreviewWidget(
                label: "Temperature Control",
                detailLabel: "3",
                mappings: [
                    OpenHABWidgetMapping(command: "manual", label: "Manual"),
                    OpenHABWidgetMapping(command: "calendar", label: "Calendar"),
                    OpenHABWidgetMapping(command: "automatic", label: "Automatic")
                ],
                selectedState: "automatic"
            ),
            fallbackSymbol: .thermometerMedium
        )
    }
}

#Preview("Multiple Segments (4)") {
    PreviewList {
        SegmentedRowView(
            widget: SegmentedRowView.createPreviewWidget(
                label: "Fan Speed",
                detailLabel: "4",
                mappings: [
                    OpenHABWidgetMapping(command: "0", label: "Off"),
                    OpenHABWidgetMapping(command: "1", label: "Low"),
                    OpenHABWidgetMapping(command: "2", label: "Med"),
                    OpenHABWidgetMapping(command: "3", label: "High")
                ],
                selectedState: "3"
            ),
            fallbackSymbol: .fanOscillation
        )
    }
}

#Preview("PressRelease") {
    PreviewList {
        SegmentedRowView(
            widget: SegmentedRowView.createPreviewWidget(
                label: "All Shutters",
                detailLabel: "NA",
                mappings: [
                    OpenHABWidgetMapping(command: "DOWN", label: "DOWN", releaseCommand: "OFF")
                ],
                selectedState: "DOWN"
            ),
            fallbackSymbol: .romanShadeClosed
        )
    }
}

#Preview("Single Mapping") {
    PreviewList {
        SegmentedRowView(
            widget: SegmentedRowView.createPreviewWidget(
                label: "Scene",
                mappings: [
                    OpenHABWidgetMapping(command: "RUN", label: "Run")
                ],
                selectedState: "RUN"
            ),
            fallbackSymbol: .theatermasksFill
        )
    }
}

#Preview("All Scenarios") {
    PreviewList {
        SegmentedRowView(
            widget: SegmentedRowView.createPreviewWidget(
                label: "Light",
                detailLabel: "1",
                mappings: [
                    OpenHABWidgetMapping(command: "ON", label: "ON"),
                    OpenHABWidgetMapping(command: "OFF", label: "OFF")
                ],
                selectedState: "ON"
            ),
            fallbackSymbol: .lightbulbFill
        )
        SegmentedRowView(
            widget: SegmentedRowView.createPreviewWidget(
                label: "Climate Mode",
                detailLabel: "2",
                mappings: [
                    OpenHABWidgetMapping(command: "m", label: "Manual"),
                    OpenHABWidgetMapping(command: "a", label: "Auto"),
                    OpenHABWidgetMapping(command: "s", label: "Schedule")
                ],
                selectedState: "a"
            ),
            fallbackSymbol: .thermometerMedium
        )
        SegmentedRowView(
            widget: SegmentedRowView.createPreviewWidget(
                label: "Fan Speed",
                detailLabel: "2",
                mappings: [
                    OpenHABWidgetMapping(command: "0", label: "Off"),
                    OpenHABWidgetMapping(command: "1", label: "Low"),
                    OpenHABWidgetMapping(command: "2", label: "Med"),
                    OpenHABWidgetMapping(command: "3", label: "High")
                ],
                selectedState: "2"
            ),
            fallbackSymbol: .fanOscillation
        )
        SegmentedRowView(
            widget: SegmentedRowView.createPreviewWidget(
                label: "Charts Period",
                mappings: [
                    OpenHABWidgetMapping(command: "D", label: "Day"),
                    OpenHABWidgetMapping(command: "W", label: "Week"),
                    OpenHABWidgetMapping(command: "M", label: "M"),
                    OpenHABWidgetMapping(command: "4h", label: "4h")
                ],
                selectedState: "D"
            ),
            fallbackSymbol: .chartBarFill
        )
        SegmentedRowView(
            widget: SegmentedRowView.createPreviewWidget(
                label: "All Shutters",
                detailLabel: "NA",
                mappings: [
                    OpenHABWidgetMapping(command: "DOWN", label: "DOWN", releaseCommand: "OFF"),
                    OpenHABWidgetMapping(command: "UP", label: " UP ", releaseCommand: "OFF")

                ],
                selectedState: "DOWN"
            ),
            fallbackSymbol: .romanShadeClosed
        )

        SegmentedRowView(
            widget: SegmentedRowView.createPreviewWidget(
                label: "Office Shutter",
                detailLabel: "NA",
                mappings: [
                    OpenHABWidgetMapping(command: "DOWN", label: "DOWN", releaseCommand: "OFF"),
                    OpenHABWidgetMapping(command: "UP", label: "UP", releaseCommand: "OFF")
                ],
                selectedState: "DOWN"
            ),
            fallbackSymbol: .romanShadeClosed
        )

        SegmentedRowView(
            widget: SegmentedRowView.createPreviewWidget(
                label: "Scene",
                mappings: [
                    OpenHABWidgetMapping(command: "RUN", label: "DOWN")
                ],
                selectedState: "DOWN"
            ),
            fallbackSymbol: .theatermasksFill
        )
    }
}

#Preview("From PreviewConstants") {
    PreviewList {
        SegmentedRowView(
            widget: PreviewConstants.openHABSitemapPage!.widgets[4],
            fallbackSymbol: .switch2
        )
    }
}
