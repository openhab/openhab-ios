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
    let widget: OpenHABWidget
    let viewModel: SitemapPageViewModel
}

@MainActor
private func makeTextInputRowContent(_ config: TextInputRowConfig) -> TextInputRowContent {
    TextInputRowContent(
        input: config.input,
        iconWidget: config.widget,
        inputHint: config.input.inputHint
    ) { command in
        config.viewModel.sendCommand(command, for: config.widget)
    }
}

private struct TextInputRowContent: View {
    let input: InputRowInput
    let iconWidget: OpenHABWidget
    let inputHint: OpenHABWidget.InputHint?
    let onSendCommand: (String) -> Void

    @State private var inputText = ""
    @FocusState private var isTextFieldFocused: Bool

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetTextInputView")

    var body: some View {
        let displayState = input.displayState
        HStack {
            IconView(widget: iconWidget)
                .frame(width: 32, height: 32)

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
    let rowID: RowID
    let input: InputRowInput
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        if let widget = viewModel.widget(for: rowID) {
            makeTextInputRowContent(
                TextInputRowConfig(
                    input: input,
                    widget: widget,
                    viewModel: viewModel
                )
            )
        } else {
            EmptyView()
        }
    }
}

struct TextInputRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        makeTextInputRowContent(
            TextInputRowConfig(
                input: InputRowInput.from(widget: widget),
                widget: widget,
                viewModel: viewModel
            )
        )
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[17]
    VStack {
        TextInputRowView(widget: widget)
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
