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
import SwiftUI

struct SegmentRow: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var settings: AppSettings
    @State private var selectedIndex: Int?

    private var currentIndex: Int {
        selectedIndex ?? widget.mappingIndex(byCommand: widget.item?.state).map { Int($0) } ?? 0
    }

    var body: some View {
        HStack {
            HStack {
                IconView(widget: widget, settings: settings)
                TextLabelView(widget: widget, lineLimit: 1)
                Spacer()
            }
            NavigationLink(destination: LazyView(SegmentSelectionView(widget: widget, selectedIndex: $selectedIndex))) {
                HStack {
                    if currentIndex >= 0, currentIndex < widget.mappingsOrItemOptions.count {
                        Text(widget.mappingsOrItemOptions[currentIndex].label)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Image(systemSymbol: .chevronRight)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .frame(height: 30)
                .background(Capsule().fill(Color.gray.opacity(0.5)))
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

#Preview {
    let widget = UserData(preview: true).widgets[4]
    return Group {
        SegmentRow(widget: widget)
        SegmentRow(widget: widget)
    }
    .environmentObject(AppSettings())
}
