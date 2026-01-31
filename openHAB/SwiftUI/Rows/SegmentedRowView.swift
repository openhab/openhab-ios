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
import SwiftUI

struct SegmentedRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetSegmentedView")

    private var mappings: [OpenHABWidgetMapping] {
        widget.mappingsOrItemOptions
    }

    @State private var selectedIndex: Int?
    @State private var pressedIndex: Int?

    var body: some View {
        HStack(spacing: 0) {
            IconView(widget: widget)
                .frame(width: 32, height: 32)

            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1) // Truncates second
            }

            Spacer(minLength: 8)

            if let detailTextLabel = widget.labelValue, !detailTextLabel.isEmpty {
                Text(detailTextLabel)
                    .foregroundStyle(widget.valuecolor.isEmpty ? Color(uiColor: UIColor.ohSecondaryLabel) : Color(fromString: widget.valuecolor))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(0) // Lower priority: truncates first when space is constrained
            }

            if !mappings.isEmpty {
                if widget.hasPressReleaseMappings {
                    // Press-release buttons for mappings with releaseCommand
                    pressReleaseButtons
                        .padding(.leading, 8)
                        .fixedSize(horizontal: true, vertical: false)
                } else {
                    // Button-based segmented control with animated selection indicator
                    segmentedButtons
                        .padding(.leading, 8)
                        .frame(minWidth: 75)
                }
            }
        }
        .padding(.trailing, 20)
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
                    .fill(Color(uiColor: .systemGray5))

                // Layer 2: Selection indicator (lighter, more visible)
                if let selectedIndex, !mappings.isEmpty {
                    let segmentWidth = geometry.size.width / CGFloat(mappings.count)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(uiColor: .systemGray3))
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
        HStack {
            ForEach(mappings.indices, id: \.self) { index in
                let mapping = mappings[index]
                pressReleaseButton(for: mapping, at: index)
            }
        }
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
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(minWidth: 40, maxWidth: 120)
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func pressReleaseButton(for mapping: OpenHABWidgetMapping, at index: Int) -> some View {
        Text(mapping.label)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(pressedIndex == index ? Color(uiColor: .systemGray3) : Color(uiColor: .systemGray5))
            )
            .foregroundStyle(.primary)
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

private extension SegmentedRowView {
    static func createPreviewWidget(
        label: String,
        detailLabel: String? = nil,
        mappings: [OpenHABWidgetMapping],
        selectedState: String? = nil
    ) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = UUID().uuidString
        widget.label = label
        widget.type = .switchWidget
        widget.mappings = mappings
        
        if let detailLabel {
            let item = OpenHABItem(
                name: "",
                type: "String",
                state: selectedState ?? mappings.first?.command ?? "",
                link: "",
                label: detailLabel,
                groupType: nil,
                stateDescription: nil,
                commandDescription: nil,
                members: [],
                category: nil,
                options: nil
            )
            widget.item = item
        }
        
        return widget
    }
}

// MARK: - Previews

#Preview("Short Labels") {
    let widget = SegmentedRowView.createPreviewWidget(
        label: "Light Switch",
        detailLabel: "Status",
        mappings: [
            OpenHABWidgetMapping(command: "ON", label: "ON"),
            OpenHABWidgetMapping(command: "OFF", label: "OFF")
        ],
        selectedState: "ON"
    )
    
    VStack(spacing: 20) {
        SegmentedRowView(widget: widget)
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}

#Preview("Long Labels") {
    let widget = SegmentedRowView.createPreviewWidget(
        label: "Temperature Control Mode",
        detailLabel: "Current Mode",
        mappings: [
            OpenHABWidgetMapping(command: "manual", label: "Manual Override"),
            OpenHABWidgetMapping(command: "calendar", label: "Calendar Based"),
            OpenHABWidgetMapping(command: "automatic", label: "Fully Automatic")
        ],
        selectedState: "automatic"
    )
    
    VStack(spacing: 20) {
        SegmentedRowView(widget: widget)
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}

#Preview("Multiple Segments (4)") {
    let widget = SegmentedRowView.createPreviewWidget(
        label: "Fan Speed",
        detailLabel: "Level 3",
        mappings: [
            OpenHABWidgetMapping(command: "0", label: "Off"),
            OpenHABWidgetMapping(command: "1", label: "Low"),
            OpenHABWidgetMapping(command: "2", label: "Med"),
            OpenHABWidgetMapping(command: "3", label: "High")
        ],
        selectedState: "3"
    )
    
    VStack(spacing: 20) {
        SegmentedRowView(widget: widget)
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}

#Preview("Narrow Labels (2 segments)") {
    let widget = SegmentedRowView.createPreviewWidget(
        label: "Door Lock",
        mappings: [
            OpenHABWidgetMapping(command: "lock", label: "🔒"),
            OpenHABWidgetMapping(command: "unlock", label: "🔓")
        ],
        selectedState: "lock"
    )
    
    VStack(spacing: 20) {
        SegmentedRowView(widget: widget)
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}

#Preview("Press-Release Buttons") {
    let widget = SegmentedRowView.createPreviewWidget(
        label: "Blinds Control",
        detailLabel: "Position",
        mappings: [
            OpenHABWidgetMapping(command: "UP", label: "Up", releaseCommand: "STOP"),
            OpenHABWidgetMapping(command: "DOWN", label: "Down", releaseCommand: "STOP")
        ]
    )
    
    VStack(spacing: 20) {
        SegmentedRowView(widget: widget)
        Text("Press and hold buttons to move blinds")
            .font(.caption)
            .foregroundColor(.secondary)
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}

#Preview("Press-Release (Multiple)") {
    let widget = SegmentedRowView.createPreviewWidget(
        label: "Garage Door",
        mappings: [
            OpenHABWidgetMapping(command: "OPEN", label: "Open", releaseCommand: "STOP"),
            OpenHABWidgetMapping(command: "CLOSE", label: "Close", releaseCommand: "STOP"),
            OpenHABWidgetMapping(command: "PARTIAL", label: "Partial", releaseCommand: "STOP")
        ]
    )
    
    VStack(spacing: 20) {
        SegmentedRowView(widget: widget)
        Text("Hold to perform action, release to stop")
            .font(.caption)
            .foregroundColor(.secondary)
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}

#Preview("Truncation Test") {
    let widget = SegmentedRowView.createPreviewWidget(
        label: "Very Long Label That Should Truncate Nicely",
        detailLabel: "Also A Very Long Detail Text Here",
        mappings: [
            OpenHABWidgetMapping(command: "option1", label: "First"),
            OpenHABWidgetMapping(command: "option2", label: "Second")
        ],
        selectedState: "option1"
    )
    
    VStack(spacing: 20) {
        SegmentedRowView(widget: widget)
        Text("Tests label truncation behavior")
            .font(.caption)
            .foregroundColor(.secondary)
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}

#Preview("All Scenarios") {
    ScrollView {
        VStack(spacing: 16) {
            // Short labels
            SegmentedRowView(widget: SegmentedRowView.createPreviewWidget(
                label: "Light",
                mappings: [
                    OpenHABWidgetMapping(command: "ON", label: "ON"),
                    OpenHABWidgetMapping(command: "OFF", label: "OFF")
                ],
                selectedState: "ON"
            ))
            
            Divider()
            
            // Long labels
            SegmentedRowView(widget: SegmentedRowView.createPreviewWidget(
                label: "Climate Mode",
                detailLabel: "Auto",
                mappings: [
                    OpenHABWidgetMapping(command: "m", label: "Manual"),
                    OpenHABWidgetMapping(command: "a", label: "Automatic"),
                    OpenHABWidgetMapping(command: "s", label: "Schedule")
                ],
                selectedState: "a"
            ))
            
            Divider()
            
            // Press-release
            SegmentedRowView(widget: SegmentedRowView.createPreviewWidget(
                label: "Shutter",
                mappings: [
                    OpenHABWidgetMapping(command: "UP", label: "↑", releaseCommand: "STOP"),
                    OpenHABWidgetMapping(command: "DOWN", label: "↓", releaseCommand: "STOP")
                ]
            ))
            
            Divider()
            
            // Multiple segments
            SegmentedRowView(widget: SegmentedRowView.createPreviewWidget(
                label: "Speed",
                mappings: [
                    OpenHABWidgetMapping(command: "0", label: "Off"),
                    OpenHABWidgetMapping(command: "1", label: "Low"),
                    OpenHABWidgetMapping(command: "2", label: "Mid"),
                    OpenHABWidgetMapping(command: "3", label: "High")
                ],
                selectedState: "2"
            ))
            
            Spacer()
        }
        .padding()
    }
    .environmentObject(SitemapPageViewModel())
}

#Preview("Button Types Comparison") {
    ScrollView {
        VStack(spacing: 24) {
            // Header
            Text("Segmented Control vs Press-Release Buttons")
                .font(.headline)
                .padding(.top)
            
            // Regular Segmented Control
            VStack(alignment: .leading, spacing: 8) {
                Text("Regular Segmented Control")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Tap to select, animated indicator shows selection")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SegmentedRowView(widget: SegmentedRowView.createPreviewWidget(
                    label: "Light Mode",
                    detailLabel: "Auto",
                    mappings: [
                        OpenHABWidgetMapping(command: "manual", label: "Manual"),
                        OpenHABWidgetMapping(command: "auto", label: "Auto"),
                        OpenHABWidgetMapping(command: "schedule", label: "Schedule")
                    ],
                    selectedState: "auto"
                ))
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(12)
            
            Divider()
            
            // Press-Release Buttons
            VStack(alignment: .leading, spacing: 8) {
                Text("Press-Release Buttons")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Hold to activate, release to stop")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SegmentedRowView(widget: SegmentedRowView.createPreviewWidget(
                    label: "Blinds",
                    detailLabel: "Control",
                    mappings: [
                        OpenHABWidgetMapping(command: "UP", label: "↑", releaseCommand: "STOP"),
                        OpenHABWidgetMapping(command: "DOWN", label: "↓", releaseCommand: "STOP")
                    ]
                ))
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(12)
            
            // Key Differences
            VStack(alignment: .leading, spacing: 12) {
                Text("Key Differences")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "hand.tap")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Segmented Control")
                            .fontWeight(.medium)
                        Text("• Single tap to select\n• Animated selection indicator\n• Stays selected until changed\n• No releaseCommand")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "hand.point.up.left")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Press-Release Buttons")
                            .fontWeight(.medium)
                        Text("• Hold down to activate\n• Independent rounded buttons\n• Sends command on press\n• Sends releaseCommand on release")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
    }
    .environmentObject(SitemapPageViewModel())
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[4]
    VStack {
        SegmentedRowView(widget: widget)
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
