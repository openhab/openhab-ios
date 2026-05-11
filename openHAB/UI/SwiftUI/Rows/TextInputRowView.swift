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
import Flow
import OpenHABCore
import os.log
import SwiftUI

struct InputCommandFormatter {
    var decimalSeparator: String = Locale.current.decimalSeparator ?? "."

    // MARK: after typing

    func command(from rawText: String, hint: OpenHABWidget.InputHint?, unitSuffix: String = "") -> String? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch hint {
        case .number:
            return normalizedNumberCommand(from: trimmed).map { $0 + unitSuffix }
        default:
            return trimmed
        }
    }

    private func normalizedNumberCommand(from value: String) -> String? {
        // Must be a valid draft and contain at least one digit
        guard isValidNumberDraft(value),
              value.contains(where: \.isNumber) else { return nil }

        let isNegative = value.hasPrefix("-")
        // make things simpler by removing the minus sign, add it back at the end of the cleanup
        var normalized = isNegative ? String(value.dropFirst()) : value

        normalized = normalized.replacingOccurrences(of: decimalSeparator, with: ".")
        if normalized.hasPrefix(".") {
            normalized = "0\(normalized)"
        }

        while normalized.hasPrefix("0"), normalized.count > 1, !normalized.hasPrefix("0.") {
            normalized = String(normalized.dropFirst())
        }

        // Strip trailing dot (e.g. "3." → "3")
        if normalized.hasSuffix(".") {
            normalized = String(normalized.dropLast())
        }

        if isNegative, normalized != "0" {
            // add back previously stripped minus
            normalized = "-\(normalized)"
        }

        guard Double(normalized) != nil else { return nil }
        return normalized
    }

    // MARK: initial draft from server state

    // Extracts the numeric portion from a formatted state string, e.g. "220 °C" → "220".
    // For non-number inputs the string is returned unchanged.
    func numericDraftFromState(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        var result = ""
        var seenDecimalSep = false
        for (index, char) in text.enumerated() {
            if index == 0, char == "-" {
                result.append(char)
            } else if char.isNumber {
                result.append(char)
            } else if String(char) == decimalSeparator, !seenDecimalSep {
                seenDecimalSep = true
                result.append(char)
            } else {
                break
            }
        }
        return result
    }

    // Extracts the unit suffix from a formatted state string, e.g. "220 °C" → " °C", "220" → "".
    func unitSuffixFromState(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        var i = text.startIndex
        var seenDecimalSep = false
        var isFirst = true
        while i < text.endIndex {
            let char = text[i]
            if isFirst {
                isFirst = false
                if char == "-" {
                    i = text.index(after: i)
                    continue
                }
            }
            if char.isNumber {
                i = text.index(after: i)
            } else if String(char) == decimalSeparator, !seenDecimalSep {
                seenDecimalSep = true
                i = text.index(after: i)
            } else {
                break
            }
        }
        return String(text[i...])
    }

    // MARK: during typing

    func filteredDraftInput(from rawText: String, previousText: String, hint: OpenHABWidget.InputHint?) -> String {
        guard hint == .number else { return rawText }
        return isValidNumberDraft(rawText) ? rawText : previousText
    }

    func isValidNumberDraft(_ value: String) -> Bool {
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
    @State private var lastValidDraft = ""
    @State private var draftUnitSuffix = ""
    @State private var showInputAlert = false

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetTextInputView")
    private let inputCommandFormatter = InputCommandFormatter()
    private var formattedCommand: String? {
        inputCommandFormatter.command(from: draftInputText, hint: inputHint, unitSuffix: draftUnitSuffix)
    }

    private var alertMessage: String {
        let label = input.displayState.labelText.isEmpty ? "Unknown" : input.displayState.labelText
        let value = input.displayState.labelValue.flatMap { $0.isEmpty ? nil : $0 } ?? "Unknown"
        return "Current value for \"\(label)\" is \"\(value)\"."
    }

    var body: some View {
        let displayState = input.displayState
        RowViewWithIcon(input: input, spacing: 8) {
            HFlow(spacing: 8) {
                let labelShown = !displayState.labelText.isEmpty
                if labelShown {
                    let labelText = displayState.labelText
                    Text(labelText)
                        .ohTextToken(.rowLabel)
                        .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    let numericDraft = inputHint == .number ? inputCommandFormatter.numericDraftFromState(inputText) : inputText
                    draftInputText = numericDraft
                    lastValidDraft = numericDraft
                    draftUnitSuffix = (inputHint == .number && !numericDraft.isEmpty) ? inputCommandFormatter.unitSuffixFromState(inputText) : ""
                    showInputAlert = true
                } label: {
                    Text(inputText.isEmpty
                        ? "Enter \(inputHint == .number ? "number" : "text")"
                        : inputText)
                        .lineLimit(nil)
                        .foregroundStyle(inputText.isEmpty ? .secondary : (input.valueColor.isEmpty ? .secondary : Color(fromString: input.valueColor)))
                }
                .buttonStyle(.plain)
                .disabled(input.readOnly)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !input.readOnly else { return }
                let numericDraft = inputHint == .number ? inputCommandFormatter.numericDraftFromState(inputText) : inputText
                draftInputText = numericDraft
                lastValidDraft = numericDraft
                draftUnitSuffix = (inputHint == .number && !numericDraft.isEmpty) ? inputCommandFormatter.unitSuffixFromState(inputText) : ""
                showInputAlert = true
            }
            .alert("Enter new value", isPresented: $showInputAlert) {
                TextField("Enter text", text: $draftInputText)
                    .keyboardType(inputHint == .number ? .numbersAndPunctuation : .default)
                    .onChange(of: draftInputText) { newValue in
                        filterDraftInput(newValue)
                    }
                Button("Cancel", role: .cancel) {}
                Button("Set value", role: .destructive) {
                    sendTextCommand()
                }
                .disabled(formattedCommand == nil)
            } message: {
                Text(alertMessage)
                    .lineLimit(10)
                    .truncationMode(.tail)
            }
            .onAppear {
                inputText = displayState.effectiveState
            }
            .onChange(of: displayState.effectiveState) { newState in
                inputText = newState
            }
        }
    }

    private func filterDraftInput(_ newValue: String) {
        let filtered = inputCommandFormatter.filteredDraftInput(from: newValue, previousText: lastValidDraft, hint: inputHint)
        if filtered != newValue {
            // Defer the revert so SwiftUI picks up the new value
            // after the current TextField update cycle completes.
            Task { @MainActor in
                draftInputText = filtered
            }
        } else {
            lastValidDraft = newValue
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
