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

import CommonUI
import OpenHABCore
import os.log
import SwiftUI

struct ButtonGridButton: View {
    @ObservedObject var widget: OpenHABWidget
    let parentItem: OpenHABItem?

    @State private var isPressed = false
    @EnvironmentObject var viewModel: SitemapPageViewModel
    @State private var triggerFeedback = false

    private let logger = Logger(subsystem: "org.openhab", category: "ButtonGridButton")

    private var hasPressRelease: Bool {
        if let releaseCommand = widget.releaseCommand, !releaseCommand.isEmpty {
            return true
        }
        return false
    }

    var body: some View {
        let displayState = widget.displayState
        Button {
            // Only handle tap for non-press-release buttons;
            // press-release buttons are handled entirely by the gesture
            if !hasPressRelease {
                triggerFeedback.toggle()
                handleButtonPress()
            }
        } label: {
            HStack {
                if !widget.icon.isEmpty {
                    IconView(widget: widget)
                        .frame(width: 16, height: 16)
                } else {
                    Text(widget.label)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isChecked(displayState: displayState) ? Color.accentColor : Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isChecked(displayState: displayState) ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(widget.readOnly ?? false)
        .sensoryHeavyFeedbackIfAvailable(trigger: triggerFeedback)
        .onPressGesture(
            onPress: {
                handleTouchDown()
            },
            onRelease: {
                handleTouchUp()
            }
        )
    }

    private func handleButtonPress() {
        if let command = widget.command, !command.isEmpty {
            logger.info("Sending command: \(command)")
            sendCommand(command)
        }
    }

    private func handleTouchDown() {
        guard !isPressed else { return }
        isPressed = true
        // For press-release buttons, send command on press
        if hasPressRelease, let command = widget.command {
            triggerFeedback.toggle()
            logger.info("Sending press command: \(command)")
            sendCommand(command)
        }
    }

    private func handleTouchUp() {
        guard isPressed else { return }
        isPressed = false
        // For press-release buttons, send release command on release
        if let releaseCommand = widget.releaseCommand, !releaseCommand.isEmpty {
            logger.info("Sending release command: \(releaseCommand)")
            sendCommand(releaseCommand)
        }
    }

    private func sendCommand(_ command: String) {
        viewModel.sendCommand(
            command,
            for: widget,
            fallbackItem: parentItem
        )
    }

    private func isChecked(displayState: WidgetDisplayState) -> Bool {
        if let stateless = widget.stateless, stateless { return false }
        return displayState.effectiveState == widget.command
    }
}

private struct PressGestureModifier: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void
    @State private var pressed = false

    func body(content: Content) -> some View {
        content.gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed {
                        pressed = true
                        onPress()
                    }
                }
                .onEnded { _ in
                    pressed = false
                    onRelease()
                }
        )
    }
}

struct ButtonGridRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel

    private let logger = Logger(subsystem: "org.openhab", category: "ButtonGridRowView")

    // Maximum number of columns based on screen width
    private let maxColumns = 12

    private var buttons: [OpenHABWidget] {
        let childButtons = widget.widgets // .filter(\.visibility)
        let mappingButtons = widget.mappings.enumerated().map { (index, mapping) in
            mapping.toWidget(widgetId: "\(widget.widgetId)-mappings-\(index)", item: widget.item)
        }
        return childButtons + mappingButtons
    }

    private var showLabelAndIcon: Bool {
        !widget.label.isEmpty && widget.labelSource == .sitemapDefinition
    }

    private var gridRows: Int {
        buttons.map { $0.row ?? 1 }.max() ?? 1
    }

    private var gridColumns: Int {
        min(buttons.map { $0.column ?? 1 }.max() ?? 1, maxColumns)
    }

    var body: some View {
        let displayState = widget.displayState
        VStack(alignment: .leading, spacing: 8) {
            if showLabelAndIcon {
                HStack {
                    IconView(widget: widget)
                        .frame(width: 32, height: 32)

                    if !displayState.labelText.isEmpty {
                        let labelText = displayState.labelText
                        Text(labelText)
                            .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
                            .lineLimit(1)
                    }

                    Spacer()
                }
            }
            HStack {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: gridColumns), spacing: 8) {
                    ForEach(0 ..< gridRows, id: \.self) { row in
                        ForEach(0 ..< gridColumns, id: \.self) { column in
                            let button = buttonForPosition(row: row, column: column)

                            if let button,
                               button.visibility {
                                ButtonGridButton(widget: button, parentItem: widget.item)
                                    .id(viewModel.pageId + button.widgetId)
                            } else {
                                // Empty cell to maintain grid structure
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(height: 44)
                            }
                        }
                    }
                }
            }
        }
    }

    private func buttonForPosition(row: Int, column: Int) -> OpenHABWidget? {
        buttons.first { button in
            // OpenHAB uses 1-based indexing, convert to 0-based
            (button.row ?? 1) - 1 == row && (button.column ?? 1) - 1 == column
        }
    }
}

// Extension to convert OpenHABWidgetMapping to OpenHABWidget
extension OpenHABWidgetMapping {
    func toWidget(widgetId: String, item: OpenHABItem?) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = widgetId
        widget.id = widgetId
        widget.label = label
        widget.command = command
        widget.item = item
        widget.type = .button
        widget.visibility = true
        widget.row = row
        widget.column = column
        widget.releaseCommand = releaseCommand
        widget.stateless = true
        widget.icon = icon ?? ""
        return widget
    }
}

/// A SwiftUI View extension to handle press and release gesture events.
/// Used specifically for button grid buttons that need to send commands on press and release
/// (supporting the releaseCommand feature from openHAB).
extension View {
    func onPressGesture(onPress: @escaping () -> Void,
                        onRelease: @escaping () -> Void) -> some View {
        modifier(PressGestureModifier(onPress: onPress, onRelease: onRelease))
    }
}

#Preview {
    if let widget = PreviewConstants.openHABSitemapPage!.widgets.first(where: { $0.type == .buttongrid }) {
        VStack {
            ButtonGridRowView(widget: widget)
                .padding()
            Spacer()
        }
        .environmentObject(SitemapPageViewModel())
    } else {
        Text("No button grid widget found")
    }
}
