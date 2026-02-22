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

enum InputCommandFormatter {
    static func command(from rawText: String, hint: OpenHABWidget.InputHint?) -> String? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard hint == .number else { return trimmed }
        return normalizedNumberCommand(from: trimmed)
    }

    private static func normalizedNumberCommand(from value: String) -> String? {
        let pattern = /^[+-]?(?:\d+(?:[.,]\d+)?|[.,]\d+)(?:[eE][+-]?\d+)?$/
        guard value.wholeMatch(of: pattern) != nil else { return nil }

        let hasDot = value.contains(".")
        let hasComma = value.contains(",")
        guard !(hasDot && hasComma) else { return nil }

        var normalized = value.replacingOccurrences(of: ",", with: ".")
        if normalized.hasPrefix(".") {
            normalized = "0\(normalized)"
        } else if normalized.hasPrefix("-.") {
            normalized = "-0" + String(normalized.dropFirst(1))
        } else if normalized.hasPrefix("+.") {
            normalized = "+0" + String(normalized.dropFirst(1))
        }

        guard Double(normalized) != nil else { return nil }
        return normalized
    }
}

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
    @State private var draftInputText = ""
    @State private var showInputAlert = false

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetTextInputView")
    private var formattedCommand: String? {
        InputCommandFormatter.command(from: draftInputText, hint: inputHint)
    }

    private var alertMessage: String {
        let label = input.displayState.labelText.isEmpty ? "Unknown" : input.displayState.labelText
        let value = input.displayState.labelValue.flatMap { $0.isEmpty ? nil : $0 } ?? "Unknown"
        return "Current value for \(label) is \(value)"
    }

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

            Button {
                draftInputText = inputText
                showInputAlert = true
            } label: {
                Text(inputText.isEmpty ? "Enter text" : inputText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(inputText.isEmpty ? .secondary : (input.valueColor.isEmpty ? .secondary : Color(fromString: input.valueColor)))
            }
            .buttonStyle(.plain)
            .disabled(input.readOnly)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !input.readOnly else { return }
            draftInputText = inputText
            showInputAlert = true
        }
        .alert("Enter new value", isPresented: $showInputAlert) {
            TextField("Enter text", text: $draftInputText)
                .keyboardType(inputHint == .number ? .numbersAndPunctuation : .default)
            Button("Cancel", role: .cancel) {}
            Button("Set value", role: .destructive) {
                sendTextCommand()
            }
            .disabled(formattedCommand == nil)
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            inputText = displayState.effectiveState
        }
        .onChange(of: displayState.effectiveState) { newState in
            inputText = newState
        }
    }

    private func sendTextCommand() {
        guard let command = formattedCommand else {
            logger.warning("Skipping invalid input command for hint \(String(describing: inputHint?.rawValue), privacy: .public)")
            return
        }
        logger.info("Sending text command: \(command)")
        onSendCommand(command)
    }
}

struct TextInputRowView: View {
    let input: InputRowInput
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        makeTextInputRowContent(
            TextInputRowConfig(
                input: input) { command in
                    guard let itemName = input.itemName else { return }
                    viewModel.sendCommand(command, for: itemName)
                    // swiftlint:disable:next closure_end_indentation
                }
        )
    }
}

#if DEBUG
#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[17]
    VStack {
        TextInputRowView(input: InputRowInput.from(widget: widget))
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
#endif
