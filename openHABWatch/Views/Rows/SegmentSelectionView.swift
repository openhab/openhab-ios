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

import OpenHABCore
import SwiftUI

struct SegmentSelectionView: View {
    let widget: OpenHABWidget
    let stateToken: String
    @Binding var selectedIndex: Int?
    @Environment(\.dismiss) private var dismiss
    @State private var pressedIndex: Int?
    @State private var viewModel: WidgetRowViewModel
    @State private var commandSender = WidgetCommandDispatcher()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0 ..< viewModel.mappings.count, id: \.self) { index in
                    let mapping = viewModel.mappings[index]

                    if viewModel.hasPressReleaseMappings {
                        // Press-release button for mappings with releaseCommand
                        pressReleaseButton(for: mapping, at: index)
                    } else {
                        // Standard button for regular mappings
                        standardButton(for: mapping, at: index)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.labelText)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedIndex = viewModel.selectedIndex
        }
        .onChange(of: stateToken, initial: false) { _, _ in
            viewModel.update(from: widget)
            selectedIndex = viewModel.selectedIndex
        }
    }

    init(widget: OpenHABWidget, stateToken: String, selectedIndex: Binding<Int?>) {
        self.widget = widget
        self.stateToken = stateToken
        _selectedIndex = selectedIndex
        let viewModel = WidgetRowViewModel(widget: widget)
        _viewModel = State(wrappedValue: viewModel)
    }

    private func standardButton(for mapping: OpenHABWidgetMapping, at index: Int) -> some View {
        Button {
            selectOption(at: index)
        } label: {
            optionLabel(for: mapping, at: index, isPressed: false)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func pressReleaseButton(for mapping: OpenHABWidgetMapping, at index: Int) -> some View {
        optionLabel(for: mapping, at: index, isPressed: pressedIndex == index)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if pressedIndex != index {
                            pressedIndex = index
                            commandSender.sendPress(mapping.command, for: widget)
                        }
                    }
                    .onEnded { _ in
                        pressedIndex = nil
                        commandSender.sendRelease(mapping.releaseCommand, for: widget)
                    }
            )
    }

    private func optionLabel(for mapping: OpenHABWidgetMapping, at index: Int, isPressed: Bool) -> some View {
        HStack {
            Text(mapping.label)
                .foregroundStyle(.primary)
                .watchTextStyle(.label)
            Spacer()
            if isSelected(index: index), !viewModel.hasPressReleaseMappings {
                Image(systemSymbol: .checkmark)
                    .foregroundStyle(Color.accentColor)
                    .watchTextStyle(.control)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor(for: index, isPressed: isPressed))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .accessibilityLabel(mapping.label)
        .accessibilityAddTraits(.isButton)
    }

    private func backgroundColor(for index: Int, isPressed: Bool) -> Color {
        if isPressed {
            Color.accentColor.opacity(0.4)
        } else if isSelected(index: index) {
            Color.accentColor.opacity(0.2)
        } else {
            Color.clear
        }
    }

    private func isSelected(index: Int) -> Bool {
        selectedIndex == index
    }

    private func selectOption(at index: Int) {
        selectedIndex = index
        if let selectedCommand = viewModel.mappings[safe: index]?.command {
            commandSender.send(
                selectedCommand,
                for: widget,
                policy: WidgetCommandDefaults.immediate,
                key: "segment-selection"
            )
            dismiss()
        }
    }
}

#Preview {
    @Previewable @State var selectedIndex: Int? = 0
    let widget = PreviewWidgetFactory.segmented(
        label: "Climate Mode",
        mappings: [
            OpenHABWidgetMapping(command: "manual", label: "Manual"),
            OpenHABWidgetMapping(command: "auto", label: "Auto"),
            OpenHABWidgetMapping(command: "schedule", label: "Schedule")
        ],
        selectedState: "auto",
        icon: "temperature"
    )
    return PreviewNavigationContainer {
        SegmentSelectionView(
            widget: widget,
            stateToken: widget.item?.state ?? widget.state,
            selectedIndex: $selectedIndex
        )
    }
}
