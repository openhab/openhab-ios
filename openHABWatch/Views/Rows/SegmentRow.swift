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
    @State private var pendingValue: String?

    var valueBinding: Binding<Int> {
        .init(
            get: {
                guard case let .segmented(value) = widget.stateEnumBinding else { return 0 }
                return value
            },
            set: { newValue in
                Logger.rowViews.debug("Picker new value = \(newValue)")
                widget.stateEnumBinding = .segmented(newValue)
                if let selectedCommand = widget.mappingsOrItemOptions[safe: newValue]?.command {
                    pendingValue = selectedCommand
                    Logger.rowViews.debug("Selected command: \(selectedCommand)")
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(500))
                        if pendingValue == selectedCommand { // Ensure no new updates came in
                            widget.sendCommand(selectedCommand)
                            pendingValue = nil
                        }
                    }
                }
            }
        )
    }

    var body: some View {
        HStack {
            HStack {
                IconView(widget: widget, settings: settings)
                TextLabelView(widget: widget, lineLimit: 1)
                Spacer()
            }
            NavigationLink(destination: LazyView(SegmentSelectionView(widget: widget))) {
                HStack {
                    if let selectedIndex = widget.mappingsOrItemOptions.indices.first(where: { index in
                        guard case let .segmented(value) = widget.stateEnumBinding else { return false }
                        return value == index
                    }) {
                        Text(widget.mappingsOrItemOptions[selectedIndex].label)
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
