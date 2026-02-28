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
    static func filteredDraftInput(from rawText: String, previousText: String, hint: OpenHABWidget.InputHint?) -> String {
        guard hint == .number else { return rawText }
        return isValidNumberDraft(rawText) ? rawText : previousText
    }

    static func command(from rawText: String, hint: OpenHABWidget.InputHint?) -> String? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard hint == .number else { return trimmed }
        return normalizedNumberCommand(from: trimmed)
    }

    static func isValidNumberDraft(_ value: String, decimalSeparator: String = Locale.current.decimalSeparator ?? ".") -> Bool {
        if value.isEmpty { return true }

        let wholeNumberPattern = /^-?[0-9]*$/

        // Valid if it matches an optional sign followed by digits only
        if value.firstRange(of: wholeNumberPattern) != nil {
            return true
        }

        // Strip optional leading minus for decimal-separator check
        let withoutSign = value.hasPrefix("-") ? String(value.dropFirst()) : value

        // Check that after removing one decimal separator, only digits remain
        let parts = withoutSign.components(separatedBy: decimalSeparator)
        // Exactly one decimal separator yields exactly two parts
        guard parts.count == 2 else { return false }
        // Both parts must contain only digits (either may be empty, e.g. "3." or ".5")
        let digitsOnly = /^[0-9]*$/
        return parts.allSatisfy { $0.firstRange(of: digitsOnly) != nil }
    }

    private static func normalizedNumberCommand(from value: String) -> String? {
        let decimalSeparator = Locale.current.decimalSeparator ?? "."

        // Must be a valid draft and contain at least one digit
        guard isValidNumberDraft(value),
              value.contains(where: \.isNumber) else { return nil }

        var normalized = value.replacingOccurrences(of: decimalSeparator, with: ".")
        if normalized.hasPrefix(".") {
            normalized = "0\(normalized)"
        } else if normalized.hasPrefix("-.") {
            normalized = "-0" + String(normalized.dropFirst(1))
        }

        // Strip trailing dot (e.g. "3." → "3")
        if normalized.hasSuffix(".") {
            normalized = String(normalized.dropLast())
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

    private var draftInputBinding: Binding<String> {
        Binding(
            get: { draftInputText },
            set: { newValue in
                draftInputText = InputCommandFormatter.filteredDraftInput(from: newValue, previousText: draftInputText, hint: inputHint)
            }
        )
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
            TextField("Enter text", text: draftInputBinding)
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
