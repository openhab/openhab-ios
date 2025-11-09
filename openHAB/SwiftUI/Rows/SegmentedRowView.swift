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

struct SegmentedRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetSegmentedView")

    private var mappings: [OpenHABWidgetMapping] {
        widget.mappingsOrItemOptions
    }

    @State private var selectedIndex: Int?

    private var isMomentary: Bool {
        mappings.count == 1 || widget.item?.state == "NULL"
    }

    var body: some View {
        HStack {
            IconView(widget: widget)
                .frame(width: 24, height: 24)
                .padding(.top, 4) // Align with text

            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
            }
            Spacer()

            if let detailTextLabel = widget.labelValue, !detailTextLabel.isEmpty {
                Text(detailTextLabel)
                    .foregroundColor(widget.valuecolor.isEmpty ? Color(uiColor: UIColor.ohSecondaryLabel) : Color(fromString: widget.valuecolor))
                    .lineLimit(1)
            }

            if !mappings.isEmpty {
                if isMomentary {
                    HStack {
                        ForEach(mappings.indices, id: \.self) { index in
                            Button {
                                viewModel.sendCommand(widget.item, commandToSend: mappings[index].command)
                            } label: {
                                Text(mappings[index].label)
                                    .padding(.horizontal, 6)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    HStack {
                        Picker("", selection: Binding<Int>(
                            get: { selectedIndex ?? -1 },
                            set: { newIndex in
                                selectedIndex = newIndex
                                if let mapping = mappings[safe: newIndex] {
                                    viewModel.sendCommand(widget.item, commandToSend: mapping.command)
                                }
                            }
                        )) {
                            ForEach(mappings.indices, id: \.self) { index in
                                Text(mappings[index].label).tag(index)
                            }
                        }
                        .padding(.bottom, -8)
                        .padding(.top, -8)
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                    }
                }
            }
        }
        .onAppear {
            if !isMomentary {
                selectedIndex = widget.mapCommandtoIndex(with: widget.item?.state)
            }
        }
        .onChange(of: widget.item?.state) { newState in
            selectedIndex = widget.mapCommandtoIndex(with: newState)
        }
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[4]
    VStack {
        SegmentedRowView(widget: widget)
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
