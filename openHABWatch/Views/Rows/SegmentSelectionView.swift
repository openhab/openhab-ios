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
import os.log
import SwiftUI

struct SegmentSelectionView: View {
    @ObservedObject var widget: OpenHABWidget
    @Binding var selectedIndex: Int?
    @Environment(\.dismiss) private var dismiss
    @State private var pendingValue: String?
    @State private var pressedIndex: Int?
    @State private var viewModel: WidgetRowViewModel

    private var currentIndex: Int? {
        viewModel.selectedIndex
    }

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
        .navigationTitle("Select Option")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.update(from: widget)
            selectedIndex = viewModel.selectedIndex
        }
        .onChange(of: widget.item?.state, initial: false) { _, _ in
            viewModel.update(from: widget)
            selectedIndex = viewModel.selectedIndex
        }
    }

    @ViewBuilder
    private func standardButton(for mapping: OpenHABWidgetMapping, at index: Int) -> some View {
        Button {
            selectOption(at: index)
        } label: {
            optionLabel(for: mapping, at: index, isPressed: false)
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func pressReleaseButton(for mapping: OpenHABWidgetMapping, at index: Int) -> some View {
        optionLabel(for: mapping, at: index, isPressed: pressedIndex == index)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if pressedIndex != index {
                            pressedIndex = index
                            // Send command on press
                            Logger.rowViews.info("Sending press command: \(mapping.command)")
                            widget.sendCommand(mapping.command)
                        }
                    }
                    .onEnded { _ in
                        pressedIndex = nil
                        // Send release command on release
                        if let releaseCommand = mapping.releaseCommand, !releaseCommand.isEmpty {
                            Logger.rowViews.info("Sending release command: \(releaseCommand)")
                            widget.sendCommand(releaseCommand)
                        }
                    }
            )
    }

    @ViewBuilder
    private func optionLabel(for mapping: OpenHABWidgetMapping, at index: Int, isPressed: Bool) -> some View {
        HStack {
            Text(mapping.label)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            Spacer()
            if isSelected(index: index), !viewModel.hasPressReleaseMappings {
                Image(systemSymbol: .checkmark)
                    .foregroundStyle(Color.accentColor)
                    .font(.caption.weight(.bold))
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
        currentIndex == index
    }

    private func selectOption(at index: Int) {
        viewModel.selectedIndex = index
        selectedIndex = viewModel.selectedIndex
        if let selectedCommand = viewModel.mappings[safe: index]?.command {
            pendingValue = selectedCommand
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                if pendingValue == selectedCommand {
                    widget.sendCommand(selectedCommand)
                    pendingValue = nil
                    dismiss()
                }
            }
        }
    }

    init(widget: OpenHABWidget, selectedIndex: Binding<Int?>) {
        self.widget = widget
        _selectedIndex = selectedIndex
        _viewModel = State(wrappedValue: WidgetRowViewModel(widget: widget))
    }
}

#Preview {
    @Previewable @State var selectedIndex: Int? = 0
    let widget = UserData(preview: true).widgets[4]
    return NavigationStack {
        SegmentSelectionView(widget: widget, selectedIndex: $selectedIndex)
    }
    .environmentObject(AppSettings())
}
