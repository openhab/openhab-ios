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

    /// Formats a Double (always dot-decimal from the server) using the locale decimal separator.
    /// Whole numbers are rendered without a decimal point (220.0 → "220").
    func localeFormattedValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0,
           value >= Double(Int.min),
           value <= Double(Int.max) {
            return String(Int(value))
        }
        // Use a neutral locale so the output is always dot-decimal, then swap in
        // the formatter's own decimalSeparator so the result matches the user's locale.
        let dotDecimal = value.formatted(
            .number
                .precision(.fractionLength(1 ... 15))
                .grouping(.never)
                .locale(Locale(identifier: "en_US_POSIX"))
        )
        guard decimalSeparator != "." else { return dotDecimal }
        return dotDecimal.replacingOccurrences(of: ".", with: decimalSeparator)
    }

    /// Extracts the numeric portion from a formatted state string, e.g. "220 °C" → "220".
    /// For non-number inputs the string is returned unchanged.
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

    /// Extracts the unit suffix from a formatted state string, e.g. "220 °C" → " °C", "220" → "".
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

    /// Display value for number inputs: apply the number pattern with the current locale,
    /// falling back to the server-formatted label value, then the raw state string.
    private var formattedDisplayText: String {
        guard inputHint == .number, !inputText.isEmpty else { return inputText }
        if let pattern = input.numberPattern, !pattern.isEmpty {
            let numberState = inputText.parseAsNumber(format: pattern)
            if numberState.value.isFinite {
                let formatted = numberState.toString(locale: Locale.current)
                if !formatted.isEmpty { return formatted }
            }
        }
        if let labelValue = input.displayState.labelValue, !labelValue.isEmpty {
            return labelValue
        }
        return inputText
    }

    private var alertMessage: String {
        let label = input.displayState.labelText.isEmpty ? "Unknown" : input.displayState.labelText
        let value = inputText.isEmpty ? "Unknown" : formattedDisplayText
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
                    prepareEditDraft()
                    showInputAlert = true
                } label: {
                    Text(
                        inputText.isEmpty
                            ? "Enter \(inputHint == .number ? "number" : "text")"
                            : formattedDisplayText
                    )
                    .lineLimit(nil)
                    .foregroundStyle(inputText.isEmpty ? .secondary : (input.valueColor.isEmpty ? .secondary : Color(fromString: input.valueColor)))
                }
                .buttonStyle(.plain)
                .disabled(input.readOnly)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !input.readOnly else { return }
                prepareEditDraft()
                showInputAlert = true
            }
            .alert("Enter new value", isPresented: $showInputAlert) {
                TextField("Enter text", text: $draftInputText)
                    .keyboardType(inputHint == .number ? .numbersAndPunctuation : .default)
                    .onChange(of: draftInputText) { _, newValue in
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
            .onChange(of: displayState.effectiveState) { _, newState in
                inputText = newState
            }
        }
    }

    private func prepareEditDraft() {
        if inputHint == .number, !inputText.isEmpty {
            let numberState = inputText.parseAsNumber(format: input.numberPattern)
            let numericDraft = numberState.value.isFinite
                ? inputCommandFormatter.localeFormattedValue(numberState.value)
                : inputCommandFormatter.numericDraftFromState(inputText)
            draftInputText = numericDraft
            lastValidDraft = numericDraft
            if numberState.value.isFinite, let unit = numberState.unit, !unit.isEmpty {
                draftUnitSuffix = " \(unit)"
            } else {
                draftUnitSuffix = ""
            }
        } else {
            draftInputText = inputText
            lastValidDraft = inputText
            draftUnitSuffix = ""
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
                input: input
            ) { command in
                guard let itemName = input.itemName else { return }
                viewModel.sendCommand(command, for: itemName)
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
