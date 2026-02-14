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

struct TabCustomizationSection: View {
    @Binding var tabConfiguration: [TabEntry]

    var body: some View {
        Section(header: Text("Tabs")) {
            ForEach(Array(tabConfiguration.enumerated()), id: \.element.id) { index, entry in
                HStack {
                    Image(systemName: systemImage(for: entry.id))
                        .frame(width: 24)
                        .foregroundStyle(entry.enabled || entry.id == "system" ? .primary : .secondary)
                    Text(displayName(for: entry.id))
                        .foregroundStyle(entry.enabled || entry.id == "system" ? .primary : .secondary)
                    Spacer()
                    if entry.id != "system" {
                        Toggle("", isOn: $tabConfiguration[index].enabled)
                            .labelsHidden()
                    }
                }
            }
            .onMove { source, destination in
                tabConfiguration.move(fromOffsets: source, toOffset: destination)
            }
        }
        .environment(\.editMode, .constant(.active))
    }

    private func displayName(for id: String) -> String {
        switch id {
        case "main": "Home"
        case "sitemaps": "Sitemaps"
        case "tiles": "Tiles"
        case "system": "System"
        default: id.capitalized
        }
    }

    private func systemImage(for id: String) -> String {
        switch id {
        case "main": "house"
        case "sitemaps": "map"
        case "tiles": "square.grid.2x2"
        case "system": "gear"
        default: "questionmark"
        }
    }
}
