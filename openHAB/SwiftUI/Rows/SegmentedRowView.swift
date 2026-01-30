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

    private var isMomentary: Bool {
        mappings.count == 1 || widget.item?.state == "NULL"
    }

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
                } else if isMomentary {
                    HStack {
                        ForEach(mappings.indices, id: \.self) { index in
                            Button {
                                viewModel.sendCommand(widget.item, commandToSend: mappings[index].command)
                            } label: {
                                Text(mappings[index].label)
                                    .padding(.horizontal, 6)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    HStack {
                        Picker("", selection: Binding<Int>(
                            get: { selectedIndex ?? -1 },
                            set: { newIndex in
                                selectedIndex = newIndex
                                if let mapping = mappings[safe: newIndex] {
                                    viewModel.sendCommand(widget.item, commandToSend: mapping.command)
                                }
                            }
                        )) {
                            ForEach(mappings.indices, id: \.self) { index in
                                Text(mappings[index].label).tag(index)
                            }
                        }
                        .padding(.bottom, -8)
                        .padding(.top, -8)
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                    }
                }
            }
        }
        .onAppear {
            if !isMomentary {
                selectedIndex = widget.mapCommandtoIndex(with: widget.item?.state)
            }
        }
        .onChange(of: widget.item?.state) { newState in
            selectedIndex = widget.mapCommandtoIndex(with: newState)
        }
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
