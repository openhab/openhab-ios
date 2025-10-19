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

struct SegmentSelectionView: View {
    @ObservedObject var widget: OpenHABWidget
    @Environment(\.dismiss) private var dismiss
    @State private var pendingValue: String?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0 ..< widget.mappingsOrItemOptions.count, id: \.self) { index in
                    Button(action: {
                        selectOption(at: index)
                    }) {
                        HStack {
                            Text(widget.mappingsOrItemOptions[index].label)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            if isSelected(index: index) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                                    .font(.caption.weight(.bold))
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected(index: index) ? Color.accentColor.opacity(0.2) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
        .navigationTitle("Select Option")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func isSelected(index: Int) -> Bool {
        guard case let .segmented(value) = widget.stateEnumBinding else { return false }
        return value == index
    }
    
    private func selectOption(at index: Int) {
        widget.stateEnumBinding = .segmented(index)
        if let selectedCommand = widget.mappingsOrItemOptions[safe: index]?.command {
            pendingValue = selectedCommand
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { // 300ms delay
                if pendingValue == selectedCommand {
                    widget.sendCommand(selectedCommand)
                    pendingValue = nil
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    let widget = UserData(preview: true).widgets[4]
    return NavigationStack {
        SegmentSelectionView(widget: widget)
    }
    .environmentObject(AppSettings())
}
