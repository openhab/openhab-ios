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

struct WidgetSelectionView: View {
    @ObservedObject var widget: OpenHABWidget
    @State private var selectedIndex: Int = 0

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetSelectionView")

    private var mappings: [OpenHABWidgetMapping] {
        widget.mappingsOrItemOptions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(UIColor(fromString: widget.labelcolor)))
            }

            if !mappings.isEmpty {
                Picker("Selection", selection: $selectedIndex) {
                    ForEach(mappings.indices, id: \.self) { index in
                        Text(mappings[index].label)
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedIndex) { newIndex in
                    guard let mapping = mappings[safe: newIndex] else { return }
                    logger.info("Selection changed to: \(mapping.label)")
                    widget.sendCommand(mapping.command)
                }
            }

            if let labelValue = widget.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .font(.caption)
                    .foregroundColor(widget.valuecolor.isEmpty ? .secondary : Color(UIColor(fromString: widget.valuecolor)))
            }
        }
        .onAppear {
            selectedIndex = Int(widget.mappingIndex(byCommand: widget.item?.state) ?? 0)
        }
    }
}
