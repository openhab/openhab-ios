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
internal import SFSafeSymbols
import SwiftUI

/// Selection list view for picking from available options
struct SelectionListView: View {
    let widget: OpenHABWidget
    let mappings: [OpenHABWidgetMapping]
    let title: String
    @Binding var selectedIndex: Int?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var pageData: UserData
    @State private var commandSender = WidgetCommandDispatcher()

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
                                .watchTextStyle(.label)
                            Spacer()
                            if selectedIndex == index {
                                Image(systemSymbol: .checkmark)
                                    .foregroundStyle(Color.accentColor)
                                    .watchTextStyle(.control)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedIndex == index ? Color.accentColor.opacity(0.2) : Color.clear)
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
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            commandSender.confirmationHandler = { message, proceed in
                pageData.pendingCommandConfirmation = PendingCommandConfirmation(message: message, onConfirm: proceed)
            }
        }
    }

    private func selectOption(at index: Int) {
        selectedIndex = index
        if let selectedCommand = mappings[safe: index]?.command {
            commandSender.send(
                selectedCommand,
                for: widget,
                policy: .immediate,
                key: "selection-list"
            )
            dismiss()
        }
    }
}

struct SelectionRow: View {
    let widget: OpenHABWidget
    let mappings: [OpenHABWidgetMapping]
    let title: String
    let initialSelectedIndex: Int?
    let labelValue: String?
    @EnvironmentObject var settings: AppSettings
    @State private var selectedIndex: Int?

    /// Returns the label of the currently selected mapping
    private var selectedValueText: String? {
        if let index = selectedIndex,
           index >= 0,
           index < mappings.count {
            return mappings[index].label
        }
        return labelValue
    }

    private var selectedIndexBinding: Binding<Int?> {
        Binding(
            get: { selectedIndex },
            set: { selectedIndex = $0 }
        )
    }

    var body: some View {
        HStack {
            HStack {
                WatchIconView(model: widget.iconRenderModel(), settings: settings)
                WatchLabelText(text: title, labelColor: widget.labelcolor)
                Spacer()
            }
            NavigationLink(destination: LazyView(SelectionListView(
                widget: widget,
                mappings: mappings,
                title: title,
                selectedIndex: selectedIndexBinding
            ))) {
                HStack(spacing: 4) {
                    if let valueText = selectedValueText {
                        Text(valueText)
                            .foregroundStyle(widget.valuecolor.isEmpty ? .secondary : Color(fromString: widget.valuecolor))
                            .lineLimit(2)
                            .watchTextStyle(.secondary)
                    }
                    Image(systemSymbol: .chevronUpChevronDown)
                        .foregroundStyle(.secondary)
                        .watchTextStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            selectedIndex = initialSelectedIndex
        }
        .onChange(of: initialSelectedIndex) { _, newValue in
            selectedIndex = newValue
        }
    }
}

#Preview {
    let widget = PreviewWidgetFactory.selection(
        label: "Mode",
        options: [("auto", "Auto"), ("manual", "Manual"), ("away", "Away")],
        selectedIndex: 1
    )
    PreviewNavigationContainer {
        SelectionRow(
            widget: widget,
            mappings: widget.mappingsOrItemOptions,
            title: widget.labelText.isEmpty ? "Select" : widget.labelText,
            initialSelectedIndex: widget.mappingIndex(byCommand: widget.item?.state).map { Int($0) },
            labelValue: widget.labelValue
        )
    }
}

#Preview("Selection List") {
    @Previewable @State var selectedIndex: Int? = 0
    let widget = PreviewWidgetFactory.selection(
        label: "Mode",
        options: [("auto", "Auto"), ("manual", "Manual"), ("away", "Away")],
        selectedIndex: 0
    )
    PreviewNavigationContainer {
        SelectionListView(
            widget: widget,
            mappings: widget.mappingsOrItemOptions,
            title: widget.labelText.isEmpty ? "Select" : widget.labelText,
            selectedIndex: $selectedIndex
        )
    }
}
