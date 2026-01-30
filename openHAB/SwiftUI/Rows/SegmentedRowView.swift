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
        HStack {
            IconView(widget: widget)
                .frame(width: 32, height: 32)
                .padding(.top, 4) // Align with text

            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
            }
            Spacer()

            if let detailTextLabel = widget.labelValue, !detailTextLabel.isEmpty {
                Text(detailTextLabel)
                    .foregroundStyle(widget.valuecolor.isEmpty ? Color(uiColor: UIColor.ohSecondaryLabel) : Color(fromString: widget.valuecolor))
                    .lineLimit(1)
            }

            if !mappings.isEmpty {
                if widget.hasPressReleaseMappings {
                    // Press-release buttons for mappings with releaseCommand
                    pressReleaseButtons
                } else {
                    // Button-based segmented control that allows repeated clicks on same segment
                    // This matches Android app and BasicUI behavior (issue #530)
                    segmentedButtons
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

    /// Button-based segmented control that always responds to taps, even on selected segment
    @ViewBuilder
    private var segmentedButtons: some View {
        HStack(spacing: 0) {
            ForEach(0 ..< mappings.count, id: \.self) { index in
                segmentButton(at: index)

                // Add divider between segments
                if index < mappings.count - 1 {
                    Divider()
                        .frame(height: 20)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(uiColor: .systemGray6))
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
        let isSelected = selectedIndex == index
        let mapping = mappings[index]

        Button {
            logger.info("Segment tapped: \(index), command: \(mapping.command)")
            selectedIndex = index
            viewModel.sendCommand(widget.item, commandToSend: mapping.command)
        } label: {
            Text(mapping.label)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(minWidth: 40, maxWidth: 120)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
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
                    .fill(pressedIndex == index ? Color.accentColor.opacity(0.3) : Color(uiColor: .systemGray5))
            )
            .foregroundStyle(pressedIndex == index ? Color.accentColor : .primary)
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

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[4]
    VStack {
        SegmentedRowView(widget: widget)
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
