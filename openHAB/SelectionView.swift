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
    @Binding var selectionItem: OpenHABItem? // Binding to track the selected item state
    var onSelection: (Int) -> Void // Closure to handle selection

    var body: some View {
        List(0 ..< mappings.count, id: \.self) { index in
            let mapping = mappings[index]
            HStack {
                Text(mapping.label)
                Spacer()
                if selectionItem?.state == mapping.command {
                    Image(systemSymbol: .checkmark)
                        .foregroundColor(.blue)
                }
            }
            .contentShape(Rectangle()) // Ensures entire row is tappable
            .onTapGesture {
                os_log("Selected mapping %d", log: .viewCycle, type: .info, index)
                onSelection(index)
            }
        }
        .navigationTitle("Select Mapping") // Navigation title
    }
}

#Preview {
    let selectedItem: OpenHABItem? = OpenHABItem(name: "", type: "", state: "command2", link: "", label: nil, groupType: nil, stateDescription: nil, commandDescription: nil, members: [], category: nil, options: nil)

    return SelectionView(
        mappings: [
            OpenHABWidgetMapping(command: "command1", label: "Option 1"),
            OpenHABWidgetMapping(command: "command2", label: "Option 2")
        ],
        selectionItem: .constant(selectedItem)
    ) { selectedMappingIndex in
        print("Selected mapping at index \(selectedMappingIndex)")
    }
}
