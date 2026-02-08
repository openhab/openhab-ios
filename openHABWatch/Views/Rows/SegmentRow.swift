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

struct SegmentRow: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var settings: AppSettings
    @State private var selectedIndex: Int?
    @State private var pressedIndex: Int?

    private var currentIndex: Int {
        selectedIndex ?? widget.mappingIndex(byCommand: widget.item?.state).map { Int($0) } ?? 0
    }

    private var hasLabel: Bool {
        if let labelText = widget.labelText, !labelText.isEmpty {
            return true
        }
        return false
    }

    var body: some View {
        if widget.hasPressReleaseMappings {
            pressReleaseContent
        } else if widget.mappingsOrItemOptions.count == 1 {
            singleMappingContent
        } else {
            multiSegmentContent
        }
    }

    // MARK: - Press-Release

    @ViewBuilder
    private var pressReleaseContent: some View {
        if hasLabel {
            VStack(alignment: .leading, spacing: 4) {
                iconTitleRow
                HStack {
                    Spacer()
                    pressReleaseButtons
                }
            }
        } else {
            HStack {
                IconView(widget: widget, settings: settings)
                Spacer()
                pressReleaseButtons
            }
        }
    }

    @ViewBuilder
    private var pressReleaseButtons: some View {
        HStack(spacing: 8) {
            ForEach(widget.mappingsOrItemOptions.indices, id: \.self) { index in
                let mapping = widget.mappingsOrItemOptions[index]
                inlineButton(label: mapping.label, isPressed: pressedIndex == index)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if pressedIndex != index {
                                    pressedIndex = index
                                    Logger.rowViews.info("Sending press command: \(mapping.command)")
                                    widget.sendCommand(mapping.command)
                                }
                            }
                            .onEnded { _ in
                                pressedIndex = nil
                                if let releaseCommand = mapping.releaseCommand, !releaseCommand.isEmpty {
                                    Logger.rowViews.info("Sending release command: \(releaseCommand)")
                                    widget.sendCommand(releaseCommand)
                                }
                            }
                    )
            }
        }
    }

    // MARK: - Single Mapping

    @ViewBuilder
    private var singleMappingContent: some View {
        let mapping = widget.mappingsOrItemOptions[0]
        if hasLabel {
            VStack(alignment: .leading, spacing: 4) {
                iconTitleRow
                HStack {
                    Spacer()
                    Button {
                        Logger.rowViews.info("Sending command: \(mapping.command)")
                        widget.sendCommand(mapping.command)
                    } label: {
                        inlineButton(label: mapping.label, isPressed: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            HStack {
                IconView(widget: widget, settings: settings)
                Spacer()
                Button {
                    Logger.rowViews.info("Sending command: \(mapping.command)")
                    widget.sendCommand(mapping.command)
                } label: {
                    inlineButton(label: mapping.label, isPressed: false)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Multi-Segment (existing NavigationLink)

    @ViewBuilder
    private var multiSegmentContent: some View {
        HStack {
            HStack {
                IconView(widget: widget, settings: settings)
                TextLabelView(widget: widget, font: .caption)
                Spacer()
            }
            NavigationLink(destination: LazyView(SegmentSelectionView(widget: widget, selectedIndex: $selectedIndex))) {
                HStack {
                    if currentIndex >= 0, currentIndex < widget.mappingsOrItemOptions.count {
                        Text(widget.mappingsOrItemOptions[currentIndex].label)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Image(systemSymbol: .chevronRight)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .frame(height: 30)
                .background(Capsule().fill(Color.gray.opacity(0.5)))
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            selectedIndex = widget.mappingIndex(byCommand: widget.item?.state).map { Int($0) }
        }
        .onChange(of: widget.item?.state, initial: false) { _, newValue in
            selectedIndex = widget.mappingIndex(byCommand: newValue).map { Int($0) }
        }
    }

    // MARK: - Shared Components

    @ViewBuilder
    private var iconTitleRow: some View {
        HStack {
            IconView(widget: widget, settings: settings)
            TextLabelView(widget: widget, font: .caption)
            Spacer()
        }
    }

    @ViewBuilder
    private func inlineButton(label: String, isPressed: Bool) -> some View {
        Text(label)
            .font(.caption)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(isPressed ? 0.6 : 0.3))
            )
    }
}

#Preview {
    let widget = UserData(preview: true).widgets[4]
    return Group {
        SegmentRow(widget: widget)
        SegmentRow(widget: widget)
    }
    .environmentObject(AppSettings())
}
