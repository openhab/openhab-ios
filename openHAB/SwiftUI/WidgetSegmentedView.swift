// Copyright (c) 2010-2025 Contributors to the openHAB project
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

struct WidgetSegmentedView: View {
    @ObservedObject var widget: OpenHABWidget

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetSegmentedView")

    private var mappings: [OpenHABWidgetMapping] {
        widget.mappingsOrItemOptions
    }

    private var selectedIndex: Int? {
        guard !isMomentary else { return nil }
        return Int(widget.mappingIndex(byCommand: widget.item?.state) ?? -1).clamped(to: -1 ... mappings.count - 1) == -1 ? nil : Int(widget.mappingIndex(byCommand: widget.item?.state) ?? -1)
    }

    private var isMomentary: Bool {
        mappings.count == 1 || widget.item?.state == "NULL"
    }

    var body: some View {
        HStack {
            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(UIColor(fromString: widget.labelcolor)))
            }

            if !mappings.isEmpty {
                Picker("", selection: Binding<Int?>(
                    get: { selectedIndex },
                    set: { newIndex in
                        guard let index = newIndex, let mapping = mappings[safe: index] else { return }
                        logger.info("Segment pressed \(index)")
                        widget.sendCommand(mapping.command)
                    }
                )) {
                    ForEach(mappings.indices, id: \.self) { index in
                        Text(mappings[index].label)
                            .tag(index as Int?)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[4]
    WidgetSegmentedView(widget: widget)
}
