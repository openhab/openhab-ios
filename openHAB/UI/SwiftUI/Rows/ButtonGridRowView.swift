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

private struct ButtonGridRowConfig {
    let input: ButtonGridRowInput
    let onSendCommand: (String, String?, WidgetCommandPolicy, WidgetCommandPhase) -> Void
}

@MainActor
private func makeButtonGridRowContent(_ config: ButtonGridRowConfig) -> ButtonGridRowContent {
    ButtonGridRowContent(input: config.input, onSendCommand: config.onSendCommand)
}

private struct ButtonGridButton: View {
    let button: ButtonGridRowInput.ButtonInput
    let parentItemName: String?
    let onSendCommand: (String, String?, WidgetCommandPolicy, WidgetCommandPhase) -> Void

    @State private var isPressed = false
    @State private var triggerFeedback = false

    private let logger = Logger(subsystem: "org.openhab", category: "ButtonGridButton")

    private var hasPressRelease: Bool {
        if let releaseCommand = button.releaseCommand, !releaseCommand.isEmpty {
            return true
        }
        return false
    }

    var body: some View {
        Button {
            if !hasPressRelease {
                triggerFeedback.toggle()
                handleButtonPress()
            }
        } label: {
            HStack {
                if button.icon.showIcon {
                    IconInputView(input: button.icon, rowIdentity: button.id, size: CGSize(width: 16, height: 16))
                } else {
                    Text(button.label)
                        .ohTextToken(.rowValueCompact)
                        .foregroundStyle(.primary)
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
        .disabled(button.readOnly)
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

    private var isChecked: Bool {
        if button.stateless { return false }
        return button.effectiveState == button.command
    }

    private func resolveItemName() -> String? {
        button.itemName ?? parentItemName
    }

    private func handleButtonPress() {
        guard !button.command.isEmpty else { return }
        logger.info("Sending command: \(button.command)")
        onSendCommand(button.command, resolveItemName(), .immediate, .change)
    }

    private func handleTouchDown() {
        guard !isPressed else { return }
        isPressed = true
        if hasPressRelease, !button.command.isEmpty {
            triggerFeedback.toggle()
            logger.info("Sending press command: \(button.command)")
            onSendCommand(button.command, resolveItemName(), .pressRelease, .press)
        }
    }

    private func handleTouchUp() {
        guard isPressed else { return }
        isPressed = false
        if let releaseCommand = button.releaseCommand, !releaseCommand.isEmpty {
            triggerFeedback.toggle()
            logger.info("Sending release command: \(releaseCommand)")
            onSendCommand(releaseCommand, resolveItemName(), .pressRelease, .release)
        }
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

private struct ButtonGridRowContent: View {
    let input: ButtonGridRowInput
    let onSendCommand: (String, String?, WidgetCommandPolicy, WidgetCommandPhase) -> Void

    var body: some View {
        let displayState = input.displayState
        VStack(alignment: .leading, spacing: 8) {
            if input.showLabelAndIcon {
                RowViewWithIcon(input: input) {
                    if !displayState.labelText.isEmpty {
                        Text(displayState.labelText)
                            .ohTextToken(.rowLabel)
                            .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))
                    }

                    Spacer()
                }
            }
            HStack {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: input.gridColumns), spacing: 8) {
                    ForEach(0 ..< input.gridRows, id: \.self) { row in
                        ForEach(0 ..< input.gridColumns, id: \.self) { column in
                            if let button = buttonForPosition(row: row, column: column), button.visibility {
                                ButtonGridButton(
                                    button: button,
                                    parentItemName: input.parentItemName,
                                    onSendCommand: onSendCommand
                                )
                                .id("\(input.widgetId)-\(button.id)")
                            } else {
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

    private func buttonForPosition(row: Int, column: Int) -> ButtonGridRowInput.ButtonInput? {
        input.buttons.first { button in
            button.row == row && button.column == column
        }
    }
}

struct ButtonGridRowView: View {
    let input: ButtonGridRowInput
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        makeButtonGridRowContent(
            ButtonGridRowConfig(
                input: input
            ) { command, itemName, policy, phase in
                guard let itemName, !itemName.isEmpty else { return }
                viewModel.sendCommand(
                    command,
                    for: itemName,
                    policy: policy,
                    phase: phase
                )
            }
        )
    }
}

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

extension View {
    func onPressGesture(onPress: @escaping () -> Void,
                        onRelease: @escaping () -> Void) -> some View {
        modifier(PressGestureModifier(onPress: onPress, onRelease: onRelease))
    }
}

#if DEBUG
#Preview {
    if let widget = PreviewConstants.openHABSitemapPage!.widgets.first(where: { $0.type == .buttongrid }) {
        VStack {
            ButtonGridRowView(input: ButtonGridRowInput.from(widget: widget))
                .padding()
            Spacer()
        }
        .environmentObject(SitemapPageViewModel())
    } else {
        Text("No button grid widget found")
    }
}
#endif
