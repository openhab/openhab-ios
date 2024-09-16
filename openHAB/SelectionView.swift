// Copyright (c) 2010-2024 Contributors to the openHAB project
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

struct SelectionView: View {
    var mappings: [OpenHABWidgetMapping] // List of mappings (instead of AnyHashable, we use a concrete type)
    @State var selectionItemState: String? // To track the selected item state
    var onSelection: (Int) -> Void // Closure to handle selection

    private let logger = Logger(subsystem: "org.openhab.app", category: "SelectionView")

    var body: some View {
        List(0 ..< mappings.count, id: \.self) { index in
            let mapping = mappings[index]
            HStack {
                Text(mapping.label)
                Spacer()
                if selectionItemState == mapping.command {
                    Image(systemSymbol: .checkmark)
                        .foregroundColor(.blue)
                }
            }
            .contentShape(.interaction, Rectangle()) // Ensures entire row is tappable
            .onTapGesture {
                selectionItemState = mappings[index].command
                logger.info("Selected mapping \(index)")
                onSelection(index)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
        }
        .navigationTitle("Select Mapping") // Navigation title
    }
}

#Preview {
    SelectionView(
        mappings: [
            OpenHABWidgetMapping(command: "command1", label: "Option 1"),
            OpenHABWidgetMapping(command: "command2", label: "Option 2")
        ],
        selectionItemState: "command2"
    ) { selectedMappingIndex in
        print("Selected mapping at index \(selectedMappingIndex)")
    }
}
