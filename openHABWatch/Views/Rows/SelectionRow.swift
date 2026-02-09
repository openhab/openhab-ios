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

/// Selection list view for picking from available options
struct SelectionListView: View {
    @ObservedObject var widget: OpenHABWidget
    @Binding var selectedIndex: Int?
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: WidgetRowViewModel

    private var mappings: [OpenHABWidgetMapping] {
        viewModel.mappings
    }

    private var currentIndex: Int? {
        viewModel.selectedIndex
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0 ..< mappings.count, id: \.self) { index in
                    let mapping = mappings[index]
                    Button {
                        selectOption(at: index)
                    } label: {
                        HStack {
                            Text(mapping.label)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            if currentIndex == index {
                                Image(systemSymbol: .checkmark)
                                    .foregroundStyle(Color.accentColor)
                                    .font(.caption.weight(.bold))
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(currentIndex == index ? Color.accentColor.opacity(0.2) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
        .navigationTitle(widget.labelText ?? "Select")
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

    private func selectOption(at index: Int) {
        viewModel.selectedIndex = index
        selectedIndex = viewModel.selectedIndex
        if let selectedCommand = mappings[safe: index]?.command {
            Logger.rowViews.info("Selection changed to: \(selectedCommand)")
            widget.sendCommand(selectedCommand)
            dismiss()
        }
    }

    init(widget: OpenHABWidget, selectedIndex: Binding<Int?>) {
        self.widget = widget
        _selectedIndex = selectedIndex
        _viewModel = State(wrappedValue: WidgetRowViewModel(widget: widget))
    }
}

struct SelectionRow: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var settings: AppSettings
    @State private var viewModel: WidgetRowViewModel

    /// Returns the label of the currently selected mapping
    private var selectedValueText: String? {
        if let index = viewModel.selectedIndex,
           index >= 0,
           index < viewModel.mappings.count {
            return viewModel.mappings[index].label
        }
        return viewModel.labelValue
    }

    private var selectedIndexBinding: Binding<Int?> {
        Binding(
            get: { viewModel.selectedIndex },
            set: { viewModel.selectedIndex = $0 }
        )
    }

    var body: some View {
        HStack {
            HStack {
                IconView(widget: widget, settings: settings)
                TextLabelView(widget: widget, font: .caption)
                Spacer()
            }
            NavigationLink(destination: LazyView(SelectionListView(widget: widget, selectedIndex: selectedIndexBinding))) {
                HStack(spacing: 4) {
                    if let valueText = selectedValueText {
                        Text(valueText)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Image(systemSymbol: .chevronUpChevronDown)
                        .foregroundStyle(.secondary)
                        .font(.caption2)
                }
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            viewModel.update(from: widget)
        }
        .onChange(of: widget.item?.state, initial: false) { _, _ in
            viewModel.update(from: widget)
        }
    }

    init(widget: OpenHABWidget) {
        self.widget = widget
        _viewModel = State(wrappedValue: WidgetRowViewModel(widget: widget))
    }
}

#Preview {
    let widget = UserData(preview: true).widgets[4]
    SelectionRow(widget: widget)
        .environmentObject(AppSettings())
}

#Preview("Selection List") {
    @Previewable @State var selectedIndex: Int? = 0
    let widget = UserData(preview: true).widgets[4]
    NavigationStack {
        SelectionListView(widget: widget, selectedIndex: $selectedIndex)
    }
    .environmentObject(AppSettings())
}
