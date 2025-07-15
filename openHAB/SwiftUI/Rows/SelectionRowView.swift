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

import CommonUI
import OpenHABCore
import os.log
import SwiftUI

struct SelectionRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @State private var selectedIndex = 0
    @ScaledMetric(relativeTo: .body) private var pickerHeight: CGFloat = 24

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetSelectionView")

    private var mappings: [OpenHABWidgetMapping] {
        widget.mappingsOrItemOptions
    }

    var body: some View {
        HStack {
            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
            }

            Spacer()

            if !mappings.isEmpty {
                Picker("", selection: $selectedIndex) {
                    ForEach(mappings.indices, id: \.self) { index in
                        Text(mappings[index].label)
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
                .frame(height: pickerHeight) // 👈 Restrict height of the Picker
                .onChange(of: selectedIndex) { newIndex in
                    guard let mapping = mappings[safe: newIndex] else { return }
                    logger.info("Selection changed to: \(mapping.label)")
                    widget.sendCommand(mapping.command)
                }
            }
        }
        .onAppear {
            selectedIndex = Int(widget.mappingIndex(byCommand: widget.item?.state) ?? 0)
        }
    }
}
