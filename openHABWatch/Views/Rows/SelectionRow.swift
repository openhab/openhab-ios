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
import SFSafeSymbols
import SwiftUI

struct SelectionRow: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var settings: AppSettings
    @State private var selectedIndex: Int?

    private var mappings: [OpenHABWidgetMapping] {
        widget.mappingsOrItemOptions
    }

    private var currentIndex: Int? {
        selectedIndex ?? widget.mappingIndex(byCommand: widget.item?.state).map { Int($0) }
    }

    /// Returns the label of the currently selected mapping
    private var selectedValueText: String? {
        if let index = currentIndex, index >= 0, index < mappings.count {
            return mappings[index].label
        }
        return widget.labelValue
    }

    var body: some View {
        HStack {
            HStack {
                IconView(widget: widget, settings: settings)
                TextLabelView(widget: widget, lineLimit: 1)
                Spacer()
            }
            NavigationLink(destination: LazyView(SelectionListView(widget: widget, selectedIndex: $selectedIndex))) {
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
            selectedIndex = widget.mappingIndex(byCommand: widget.item?.state).map { Int($0) }
        }
        .onChange(of: widget.item?.state) { newState in
            selectedIndex = widget.mappingIndex(byCommand: newState).map { Int($0) }
        }
    }
}

/// Selection list view for picking from available options
struct SelectionListView: View {
    @ObservedObject var widget: OpenHABWidget
    @Binding var selectedIndex: Int?
    @Environment(\.dismiss) private var dismiss

    private var mappings: [OpenHABWidgetMapping] {
        widget.mappingsOrItemOptions
    }

    private var currentIndex: Int? {
        selectedIndex ?? widget.mappingIndex(byCommand: widget.item?.state).map { Int($0) }
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
    }

    private func selectOption(at index: Int) {
        selectedIndex = index
        if let selectedCommand = mappings[safe: index]?.command {
            Logger.rowViews.info("Selection changed to: \(selectedCommand)")
            widget.sendCommand(selectedCommand)
            dismiss()
        }
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
