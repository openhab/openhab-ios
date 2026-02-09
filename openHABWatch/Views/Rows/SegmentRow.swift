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
    @State private var pressedIndex: Int?
    @State private var singlePressed = false
    @State private var viewModel: WidgetRowViewModel

    private var currentIndex: Int? {
        viewModel.selectedIndex
    }

    var body: some View {
        Group {
            if viewModel.hasPressReleaseMappings {
                pressReleaseContent
            } else if viewModel.mappings.count == 1 {
                singleMappingContent
            } else {
                multiSegmentContent
            }
        }
        .onAppear {
            viewModel.update(from: widget)
        }
        .onChange(of: widget.item?.state, initial: false) { _, _ in
            viewModel.update(from: widget)
        }
    }

    // MARK: - Press-Release

    @ViewBuilder
    private var pressReleaseContent: some View {
        if viewModel.mappings.count <= 2 {
            HStack {
                IconView(widget: widget, settings: settings)
                TextLabelView(widget: widget, font: .caption)
                Spacer()
                pressReleaseButtons
                    .layoutPriority(1)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                iconTitleRow
                HStack {
                    Spacer()
                    pressReleaseButtons
                }
            }
        }
    }

    @ViewBuilder
    private var pressReleaseButtons: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.mappings.indices, id: \.self) { index in
                let mapping = viewModel.mappings[index]
                inlineButton(label: mapping.label, isPressed: pressedIndex == index)
                    .overlay {
                        GeometryReader { geometry in
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let bounds = CGRect(origin: .zero, size: geometry.size)
                                            guard bounds.contains(value.startLocation) else { return }
                                            if pressedIndex != index {
                                                pressedIndex = index
                                                Logger.rowViews.info("Sending press command: \(mapping.command)")
                                                widget.sendCommand(mapping.command)
                                            }
                                        }
                                        .onEnded { _ in
                                            guard pressedIndex == index else { return }
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

    private var selectedIndexBinding: Binding<Int?> {
        Binding(
            get: { viewModel.selectedIndex },
            set: { viewModel.selectedIndex = $0 }
        )
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
            NavigationLink(destination: LazyView(SegmentSelectionView(widget: widget, selectedIndex: selectedIndexBinding))) {
                HStack {
                    if let currentIndex, currentIndex >= 0, currentIndex < viewModel.mappings.count {
                        Text(viewModel.mappings[currentIndex].label)
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
    }

    // MARK: - Single Mapping

    @ViewBuilder
    private var singleMappingContent: some View {
        let mapping = viewModel.mappings[0]
        HStack {
            IconView(widget: widget, settings: settings)
            TextLabelView(widget: widget, font: .caption)
            Spacer()
            singleButton(for: mapping)
                .layoutPriority(1)
        }
    }

    init(widget: OpenHABWidget) {
        self.widget = widget
        _viewModel = State(wrappedValue: WidgetRowViewModel(widget: widget))
    }

    // MARK: - Single Mapping

    @ViewBuilder
    private func singleButton(for mapping: OpenHABWidgetMapping) -> some View {
        inlineButton(label: mapping.label, isPressed: singlePressed)
            .overlay {
                GeometryReader { geometry in
                    let bounds = CGRect(origin: .zero, size: geometry.size)
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    singlePressed = bounds.contains(value.location)
                                }
                                .onEnded { value in
                                    if singlePressed, bounds.contains(value.location) {
                                        Logger.rowViews.info("Sending command: \(mapping.command)")
                                        widget.sendCommand(mapping.command)
                                    }
                                    singlePressed = false
                                }
                        )
                }
            }
    }

    // MARK: - Shared Components

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
            .contentShape(RoundedRectangle(cornerRadius: 8))
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
