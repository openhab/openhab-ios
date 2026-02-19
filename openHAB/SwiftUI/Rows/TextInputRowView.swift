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

private struct TextInputRowConfig {
    let input: InputRowInput
    let onSendCommand: (String) -> Void
}

@MainActor
private func makeTextInputRowContent(_ config: TextInputRowConfig) -> TextInputRowContent {
    TextInputRowContent(
        input: config.input,
        iconInput: config.input.icon,
        inputHint: config.input.inputHint
    ) { command in
        config.onSendCommand(command)
    }
}

private struct TextInputRowContent: View {
    let input: InputRowInput
    let iconInput: RowIconInput
    let inputHint: OpenHABWidget.InputHint?
    let onSendCommand: (String) -> Void

    @State private var inputText = ""
    @FocusState private var isTextFieldFocused: Bool

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetTextInputView")

    var body: some View {
        let displayState = input.displayState
        HStack {
            IconInputView(input: iconInput, rowIdentity: input.widgetId, size: CGSize(width: 32, height: 32))

            if !displayState.labelText.isEmpty {
                let labelText = displayState.labelText
                Text(labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))
            }

            Spacer()

            TextField("Enter text", text: $inputText)
                .multilineTextAlignment(inputHint == .number ? .trailing : .leading)
                .textFieldStyle(.roundedBorder)
                .focused($isTextFieldFocused)
                .onSubmit {
                    sendTextCommand()
                }
                .disabled(input.readOnly)
        }
        .onAppear {
            inputText = displayState.effectiveState
        }
        .onChange(of: displayState.effectiveState) { newState in
            if !isTextFieldFocused {
                inputText = newState
            }
        }
    }

    private func sendTextCommand() {
        logger.info("Sending text command: \(inputText)")
        onSendCommand(inputText)
        isTextFieldFocused = false
    }
}

struct TextInputRowInputView: View {
    let input: InputRowInput
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        makeTextInputRowContent(
            TextInputRowConfig(
                input: input,
                onSendCommand: { command in
                    guard let itemName = input.itemName else { return }
                    viewModel.sendCommand(command, for: itemName)
                }
            )
        )
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[17]
    VStack {
        TextInputRowInputView(input: InputRowInput.from(widget: widget))
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
