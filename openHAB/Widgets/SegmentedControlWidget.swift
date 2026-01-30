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

/// SwiftUI implementation of segmented control widget for switches with mappings
/// This implementation allows repeated clicks on the same button to resend commands,
/// matching the behavior of Android app and BasicUI (issue #530)
struct SegmentedControlWidget: View {
    @ObservedObject var widget: OpenHABWidget
    @State private var pendingValue: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .font(.body)
            }
            
            HStack(spacing: 0) {
                ForEach(0 ..< widget.mappingsOrItemOptions.count, id: \.self) { index in
                    Button(action: {
                        selectSegment(at: index)
                    }, label: {
                        Text(widget.mappingsOrItemOptions[index].label)
                            .font(.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(segmentBackground(for: index))
                            .foregroundColor(segmentForeground(for: index))
                    })
                    .buttonStyle(PlainButtonStyle())
                    
                    if index < widget.mappingsOrItemOptions.count - 1 {
                        Divider()
                            .frame(height: 32)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private func segmentBackground(for index: Int) -> Color {
        if isSelected(index: index) {
            return Color.accentColor.opacity(0.2)
        }
        return Color.clear
    }
    
    private func segmentForeground(for index: Int) -> Color {
        if isSelected(index: index) {
            return Color.accentColor
        }
        return Color.primary
    }
    
    private func isSelected(index: Int) -> Bool {
        guard case let .segmented(value) = widget.stateEnumBinding else { return false }
        return value == index
    }
    
    /// Handles segment selection with debouncing to prevent accidental double-taps
    /// Always sends command even if same segment is selected (Android/BasicUI behavior)
    private func selectSegment(at index: Int) {
        widget.stateEnumBinding = .segmented(index)
        
        if let selectedCommand = widget.mappingsOrItemOptions[safe: index]?.command {
            pendingValue = selectedCommand
            Logger.widgets.info("Segment selected: \(index), command: \(selectedCommand)")
            
            // Debounce to prevent accidental rapid double-taps
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                if pendingValue == selectedCommand {
                    widget.sendCommand(selectedCommand)
                    pendingValue = nil
                }
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    let widget = OpenHABWidget()
    // Configure widget for preview
    widget.label = "Scene"
    widget.type = .switchWidget
    // Note: In actual use, mappings would be populated from server data
    
    return SegmentedControlWidget(widget: widget)
        .padding()
}
#endif
