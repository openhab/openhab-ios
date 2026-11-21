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

struct SelectionView: View {
    let labelText: String?
    var mappings: [OpenHABWidgetMapping] // List of mappings (instead of AnyHashable, we use a concrete type)
    @State var selectionItemState: String? // To track the selected item state
    var valuecolor = "" // Color for the selected value indicator
    var onSelection: (Int) -> Void // Closure to handle selection
    var onDismiss: (() -> Void)? // Closure to handle dismissal after selection

    var body: some View {
        List(0 ..< mappings.count, id: \.self) { index in
            let mapping = mappings[index]
            Button {
                selectionItemState = mappings[index].command
                Logger.selectionView.info("Selected mapping \(index)")
                onSelection(index)
                onDismiss?()
            } label: {
                HStack {
                    Text(mapping.label)
                    Spacer()
                    if selectionItemState == mapping.command {
                        Image(systemSymbol: .checkmark)
                            .foregroundStyle(valuecolor.isEmpty ? .blue : Color(fromString: valuecolor))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .navigationTitle(labelText ?? "Select Mapping") // Navigation title
    }
}

#Preview("Default") {
    SelectionView(
        labelText: "Test Label",
        mappings: [
            OpenHABWidgetMapping(command: "command1", label: "Option 1"),
            OpenHABWidgetMapping(command: "command2", label: "Option 2")
        ],
        selectionItemState: "command2"
    ) { _ in
    } onDismiss: {}
}

#Preview("With Valuecolor") {
    SelectionView(
        labelText: "Test Label",
        mappings: [
            OpenHABWidgetMapping(command: "ON", label: "On"),
            OpenHABWidgetMapping(command: "OFF", label: "Off")
        ],
        selectionItemState: "OFF",
        valuecolor: "red"
    ) { _ in
    } onDismiss: {}
}
