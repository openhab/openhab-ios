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

struct ButtonGridButton: View {
    let widget: OpenHABWidget

    @State private var isPressed = false
    @EnvironmentObject var viewModel: SitemapPageViewModel
    @State private var triggerFeedback = false

    private let logger = Logger(subsystem: "org.openhab", category: "ButtonGridButton")

    private var isChecked: Bool {
        if let stateless = widget.stateless {
            logger.debug("button.stateless: \(stateless)")
        } else {
            logger.debug("button.stateless: nil")
        }
        if let stateless = widget.stateless, stateless { return false }
        return widget.item?.state == widget.command
    }

    var body: some View {
        Button {
            triggerFeedback.toggle()
            handleButtonPress()
        } label: {
            HStack {
                if !widget.icon.isEmpty {
                    IconView(icon: widget.icon)
                        .frame(width: 16, height: 16)
                } else {
                    Text(widget.label)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isChecked ? Color.accentColor : Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isChecked ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
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
        // Send command on tap for mappings
        if let command = widget.command, !command.isEmpty {
            logger.info("Sending command: \(command)")
            viewModel.sendCommand(widget.item, commandToSend: widget.command)
        }
    }

    private func handleTouchDown() {
        isPressed = true
        // For buttons with releaseCommand, send command on press
        if let releaseCommand = widget.releaseCommand, !releaseCommand.isEmpty,
           let command = widget.command {
            logger.info("Sending press command: \(command)")
            widget.sendCommand(command)
        }
    }

    private func handleTouchUp() {
        isPressed = false
        // For buttons with releaseCommand, send release command on release
        if let releaseCommand = widget.releaseCommand, !releaseCommand.isEmpty {
            logger.info("Sending release command: \(releaseCommand)")
            widget.sendCommand(releaseCommand)
        }
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
        VStack(alignment: .leading, spacing: 8) {
            if showLabelAndIcon {
                HStack {
                    IconView(widget: widget)
                        .frame(width: 24, height: 24)

                    if let labelText = widget.labelText, !labelText.isEmpty {
                        Text(labelText)
                            .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
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
                                ButtonGridButton(widget: button)
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

extension View {
    func onPressGesture(onPress: @escaping () -> Void,
                        onRelease: @escaping () -> Void) -> some View {
        gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    onPress()
                }
                .onEnded { _ in
                    onRelease()
                }
        )
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
        widget.releaseCommand = ""
        widget.stateless = true
        widget.icon = icon ?? ""
        return widget
    }
}

#Preview {
    if let widget = PreviewConstants.openHABSitemapPage!.widgets.first(where: { $0.type == .buttongrid }) {
        VStack {
            ButtonGridRowView(widget: widget)
                .padding()
            Spacer()
        }
    } else {
        Text("No button grid widget found")
    }
}
