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
    let button: OpenHABWidget
    let targetWidget: OpenHABWidget

    @State private var isPressed = false

    private let logger = Logger(subsystem: "org.openhab", category: "ButtonGridButton")

    private var isStateful: Bool {
        // TODO: Mappings are typically stateless unless specified otherwise
        // Handle widgets as well
        false
    }

    private var isSelected: Bool {
        guard isStateful else { return false }
        return targetWidget.item?.state == button.command
    }

    var body: some View {
        Button {
            handleButtonPress()
        } label: {
            HStack {
                if !button.icon.isEmpty {
                    IconView(icon: button.icon)
                        .frame(width: 16, height: 16)
                } else {
                    Text(button.label)
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
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
//        .disabled(widget.readOnly)
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
        if let command = button.command, !command.isEmpty {
            logger.info("Sending command: \(command)")
            targetWidget.sendCommand(button.command)
        }
    }

    private func handleTouchDown() {
        isPressed = true
    }

    private func handleTouchUp() {
        isPressed = false
    }
}

struct ButtonGridRowView: View {
    @ObservedObject var widget: OpenHABWidget

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
                    if IconView.shouldShowIcon(for: widget) {
                        IconView(widget: widget)
                            .frame(width: 24, height: 24)
                    }

                    Text(widget.labelText ?? widget.label)
                        .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))

                    Spacer()
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: gridColumns), spacing: 8) {
                ForEach(0 ..< gridRows, id: \.self) { row in
                    ForEach(0 ..< gridColumns, id: \.self) { column in
                        let button = buttonForPosition(row: row, column: column)

                        if let button {
                            ButtonGridButton(button: button, targetWidget: widget)
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
        widget.label = label
        widget.command = command
        widget.item = item
        widget.type = .switchWidget
        widget.visibility = true
        widget.row = row
        widget.column = column
        widget.releaseCommand = releaseCommand
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
