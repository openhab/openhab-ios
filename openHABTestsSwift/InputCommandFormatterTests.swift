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

import Foundation
@testable import openHAB
import OpenHABCore
import Testing

@Suite
struct InputCommandFormatterTests {
    let formatter = InputCommandFormatter(decimalSeparator: ".")

    // MARK: - isValidNumberDraft with dot separator

    @Test
    func zeroIsValid() {
        #expect(formatter.isValidNumberDraft("0"))
    }

    @Test
    func emptyStringIsValid() {
        #expect(formatter.isValidNumberDraft(""))
    }

    @Test
    func singleDigitIsValid() {
        #expect(formatter.isValidNumberDraft("5"))
    }

    @Test
    func multipleDigitsAreValid() {
        #expect(formatter.isValidNumberDraft("123"))
    }

    @Test
    func negativeSignAloneIsValid() {
        #expect(formatter.isValidNumberDraft("-"))
    }

    @Test
    func negativeNumberIsValid() {
        #expect(formatter.isValidNumberDraft("-42"))
    }

    @Test
    func decimalNumberIsValid() {
        #expect(formatter.isValidNumberDraft("3.14"))
    }

    @Test
    func trailingDecimalIsValid() {
        #expect(formatter.isValidNumberDraft("3."))
    }

    @Test
    func leadingDecimalIsValid() {
        #expect(formatter.isValidNumberDraft(".5"))
    }

    @Test
    func negativeDecimalIsValid() {
        #expect(formatter.isValidNumberDraft("-3.14"))
    }

    @Test
    func negativeLeadingDecimalIsValid() {
        #expect(formatter.isValidNumberDraft("-.5"))
    }

    @Test
    func negativeTrailingDecimalIsValid() {
        #expect(formatter.isValidNumberDraft("-3."))
    }

    @Test
    func decimalSeparatorAloneIsValid() {
        #expect(formatter.isValidNumberDraft("."))
    }

    @Test
    func negativeDecimalSeparatorAloneIsValid() {
        #expect(formatter.isValidNumberDraft("-."))
    }

    // MARK: - isValidNumberDraft rejection cases with dot separator

    @Test
    func multipleDecimalSeparatorsRejected() {
        #expect(!formatter.isValidNumberDraft("3.1.4"))
    }

    @Test
    func plusSignRejected() {
        #expect(!formatter.isValidNumberDraft("+5"))
    }

    @Test
    func negativeSignInMiddleRejected() {
        #expect(!formatter.isValidNumberDraft("3-5"))
    }

    @Test
    func lettersRejected() {
        #expect(!formatter.isValidNumberDraft("12a3"))
    }

    @Test
    func spacesRejected() {
        #expect(!formatter.isValidNumberDraft("1 2"))
    }

    @Test
    func multipleNegativeSignsRejected() {
        #expect(!formatter.isValidNumberDraft("--5"))
    }

    @Test
    func commaRejectedWhenDotIsSeparator() {
        #expect(!formatter.isValidNumberDraft("3,14"))
    }

    // MARK: - filteredDraftInput

    @Test
    func nonNumberHintPassesThrough() {
        let result = formatter.filteredDraftInput(from: "abc!@#", previousText: "", hint: nil)
        #expect(result == "abc!@#")
    }

    @Test
    func numberHintAcceptsValidDraft() {
        let result = formatter.filteredDraftInput(from: "123", previousText: "", hint: .number)
        #expect(result == "123")
    }

    @Test
    func numberHintRejectsInvalidDraft() {
        let result = formatter.filteredDraftInput(from: "12a3", previousText: "12", hint: .number)
        #expect(result == "12")
    }

    @Test
    func numberHintAcceptsNegativeSign() {
        let result = formatter.filteredDraftInput(from: "-", previousText: "", hint: .number)
        #expect(result == "-")
    }

    // MARK: - command

    @Test
    func commandFromEmptyStringForNumberReturnsNil() {
        #expect(formatter.command(from: "", hint: .number) == nil)
    }

    @Test
    func commandFromEmptyStringForTextReturnsEmptyString() {
        #expect(formatter.command(from: "", hint: nil) == "")
    }

    @Test
    func commandFromWhitespaceForNumberReturnsNil() {
        #expect(formatter.command(from: "   ", hint: .number) == nil)
    }

    @Test
    func commandFromWhitespaceForTextReturnsEmptyString() {
        #expect(formatter.command(from: "   ", hint: nil) == "")
    }

    @Test
    func commandFromNonNumberHintReturnsTrimmed() {
        #expect(formatter.command(from: "  hello  ", hint: nil) == "hello")
    }

    @Test
    func commandFromSignOnlyReturnsNil() {
        #expect(formatter.command(from: "-", hint: .number) == nil)
    }

    @Test
    func commandFromCommaReturnsNil() {
        #expect(formatter.command(from: ".", hint: .number) == nil)
    }

    @Test
    func commandFromNegativeCommaReturnsNil() {
        #expect(formatter.command(from: "-.", hint: .number) == nil)
    }

    @Test
    func commandFromZeroIntegerReturnsNormalized() {
        #expect(formatter.command(from: "0", hint: .number) == "0")
    }

    @Test
    func commandFromNegativeZeroIntegerReturnsNormalized() {
        #expect(formatter.command(from: "-0", hint: .number) == "0")
    }

    @Test
    func commandFromIntegerReturnsNormalized() {
        #expect(formatter.command(from: "42", hint: .number) == "42")
    }

    @Test
    func commandFromNegativeIntegerReturnsNormalized() {
        #expect(formatter.command(from: "-42", hint: .number) == "-42")
    }

    @Test
    func commandFromIntegerWithCommaReturnsNormalized() {
        #expect(formatter.command(from: "42.", hint: .number) == "42")
    }

    @Test
    func commandFromNegativeIntegerWithCommaReturnsNormalized() {
        #expect(formatter.command(from: "-42.", hint: .number) == "-42")
    }

    @Test
    func commandFromIntegerWithLeadingCommaReturnsNormalized() {
        #expect(formatter.command(from: ".42", hint: .number) == "0.42")
    }

    @Test
    func commandFromNegativeIntegerWithLeadingCommaReturnsNormalized() {
        #expect(formatter.command(from: "-.42", hint: .number) == "-0.42")
    }
}

// MARK: - isValidNumberDraft with comma separator

@Suite
struct InputCommandFormatterCommaTests {
    let formatter = InputCommandFormatter(decimalSeparator: ",")

    @Test
    func commaDecimalNumberIsValid() {
        #expect(formatter.isValidNumberDraft("3,14"))
    }

    @Test
    func commaTrailingIsValid() {
        #expect(formatter.isValidNumberDraft("3,"))
    }

    @Test
    func commaLeadingIsValid() {
        #expect(formatter.isValidNumberDraft(",5"))
    }

    @Test
    func negativeCommaDecimalIsValid() {
        #expect(formatter.isValidNumberDraft("-3,14"))
    }

    @Test
    func multipleCommasRejected() {
        #expect(!formatter.isValidNumberDraft("3,1,4"))
    }

    @Test
    func dotRejectedWhenCommaIsSeparator() {
        #expect(!formatter.isValidNumberDraft("3.14"))
    }
}

// MARK: - UIKit oracle (reference implementation)

@Suite
struct InputCommandFormatterOracleTests {
    /// Port of the UIKit `textField(_:shouldChangeCharactersIn:replacementString:)` logic.
    /// Given the old text, the NSRange being replaced, and the replacement string, returns
    /// whether the edit should be accepted.
    private func uikitShouldChangeCharacters(oldString: String, range: NSRange, string: String, decimalSeparator: String) -> Bool {
        let wholeNumberRegex = /^-?[0-9]*$/

        // check for deletion
        return string.isEmpty
            // check for new negative sign
            || (
                !string.starts(with: "-") // new string does not add negative sign
                    || range.location == 0 // new string adds negative sign to beginning
                    && (
                        !oldString.starts(with: "-") // old string does not contain negative sign
                            || range.length > 0
                    )
            ) // new string replaces negative sign in old string
            // check for old negative sign
            && (
                oldString.isEmpty
                    || !oldString.starts(with: "-") // old string does not start with negative sign
                    || range.location > 0 // new string starts after negative sign in old string
                    || range.length > 0
            ) // new string replaces negative sign in old string
            // check for decimal signs
            && (
                string.firstRange(of: wholeNumberRegex) != nil // new string is whole number
                    || (
                        string.replacing(decimalSeparator, with: "", maxReplacements: 1)
                            .firstRange(of: wholeNumberRegex) != nil // new string is valid decimal number
                            && !(oldString as NSString).replacingCharacters(in: range, with: "").contains(decimalSeparator)
                    )
            ) // old string without replaced range not yet contains decimal separator
    }

    @Test(arguments: [".", ","])
    func oracleExhaustiveMultiCharPastes(sep: String) {
        let formatter = InputCommandFormatter(decimalSeparator: sep)
        // Try pasting multi-character strings into valid starting strings,
        // covering all positions and replacement lengths.
        // Oracle and isValidNumberDraft must agree on every result.
        let validStarts = ["", "1", "-", "12", "-3", "4\(sep)", "\(sep)5", "-6\(sep)7", "-\(sep)"]
        let pasteStrings = [
            "12", "99", "-1", "-", "\(sep)1", "1\(sep)", "1\(sep)2",
            "-\(sep)", "\(sep)\(sep)", "ab", "-1\(sep)2"
        ]

        for oldString in validStarts {
            for pos in 0 ... oldString.count {
                for replLen in 0 ... (oldString.count - pos) {
                    for paste in pasteStrings {
                        let range = NSRange(location: pos, length: replLen)
                        let oracleAccepted = uikitShouldChangeCharacters(
                            oldString: oldString, range: range, string: paste, decimalSeparator: sep
                        )
                        let resultString = (oldString as NSString).replacingCharacters(in: range, with: paste)
                        let draftValid = formatter.isValidNumberDraft(resultString)

                        #expect(
                            oracleAccepted == draftValid,
                            "Disagreement: \"\(oldString)\" paste \"\(paste)\" @(\(pos),\(replLen)) → \"\(resultString)\": oracle=\(oracleAccepted), draft=\(draftValid) (sep=\(sep))"
                        )
                    }
                }
            }
        }
    }

    // MARK: - Oracle-based tests: UIKit shouldChangeCharacters vs isValidNumberDraft

    //
    // The UIKit oracle validates the *edit* (replacement string + position),
    // while isValidNumberDraft validates the *resulting string*. Despite this
    // difference in approach, the two are fully equivalent: for every edit
    // the oracle accepts the result is a valid draft, and for every edit the
    // oracle rejects the result is an invalid draft.

    @Test(arguments: [".", ","])
    func oracleTypingSequences(sep: String) {
        let formatter = InputCommandFormatter(decimalSeparator: sep)
        // Simulate typing various number strings character by character.
        // At each keystroke both the oracle and isValidNumberDraft must agree.
        let sequences: [String] = [
            "0",
            "123",
            "-42",
            "3\(sep)14",
            "-3\(sep)14",
            "\(sep)5",
            "-\(sep)5",
            "0\(sep)",
            "-0\(sep)",
            "-",
            "\(sep)",
            "100",
            "-0\(sep)001"
        ]

        for sequence in sequences {
            var current = ""
            for char in sequence {
                let insertion = String(char)
                let range = NSRange(location: current.count, length: 0)
                let accepted = uikitShouldChangeCharacters(
                    oldString: current, range: range, string: insertion, decimalSeparator: sep
                )
                let hypotheticalResult = (current as NSString).replacingCharacters(in: range, with: insertion)
                let draftValid = formatter.isValidNumberDraft(hypotheticalResult)

                #expect(
                    accepted == draftValid,
                    "Disagreement typing '\(char)' on \"\(current)\" → \"\(hypotheticalResult)\": oracle=\(accepted), draft=\(draftValid) (sep=\(sep))"
                )

                if accepted {
                    current = hypotheticalResult
                }
            }
        }
    }

    @Test(arguments: [".", ","])
    func oracleRejectsSecondDecimalSeparator(sep: String) {
        let formatter = InputCommandFormatter(decimalSeparator: sep)
        let oldString = "3\(sep)1"
        let insertion = sep
        let range = NSRange(location: oldString.count, length: 0)
        let accepted = uikitShouldChangeCharacters(
            oldString: oldString, range: range, string: insertion, decimalSeparator: sep
        )
        #expect(!accepted, "Oracle should reject second decimal separator")

        let wouldBeResult = "3\(sep)1\(sep)"
        #expect(
            !formatter.isValidNumberDraft(wouldBeResult),
            "isValidNumberDraft should also reject double separator"
        )
    }

    @Test(arguments: [".", ","])
    func oracleRejectsNegativeSignInMiddle(sep: String) {
        let formatter = InputCommandFormatter(decimalSeparator: sep)
        let oldString = "12"
        let insertion = "-"
        let range = NSRange(location: 1, length: 0) // insert at position 1
        let accepted = uikitShouldChangeCharacters(
            oldString: oldString, range: range, string: insertion, decimalSeparator: sep
        )
        #expect(!accepted, "Oracle should reject minus in middle")

        let wouldBeResult = "1-2"
        #expect(
            !formatter.isValidNumberDraft(wouldBeResult),
            "isValidNumberDraft should also reject minus in middle"
        )
    }

    @Test(arguments: [".", ","])
    func oracleRejectsPlusSign(sep: String) {
        let formatter = InputCommandFormatter(decimalSeparator: sep)
        let oldString = ""
        let insertion = "+"
        let range = NSRange(location: 0, length: 0)
        let accepted = uikitShouldChangeCharacters(
            oldString: oldString, range: range, string: insertion, decimalSeparator: sep
        )
        #expect(!accepted, "Oracle should reject plus sign")
        #expect(!formatter.isValidNumberDraft("+"))
    }

    @Test(arguments: [".", ","])
    func oracleAcceptsDeletionFromEnd(sep: String) {
        let formatter = InputCommandFormatter(decimalSeparator: sep)
        let oldString = "12\(sep)3"
        // Delete last character
        let range = NSRange(location: oldString.count - 1, length: 1)
        let accepted = uikitShouldChangeCharacters(
            oldString: oldString, range: range, string: "", decimalSeparator: sep
        )
        #expect(accepted, "Oracle should accept deletion")

        let result = (oldString as NSString).replacingCharacters(in: range, with: "")
        #expect(formatter.isValidNumberDraft(result))
    }

    @Test(arguments: [".", ","])
    func oracleAcceptsReplacingNegativeSign(sep: String) {
        // Replace the negative sign with a new one (e.g. select-all and type "-")
        let oldString = "-5"
        let range = NSRange(location: 0, length: 1) // select the "-"
        let accepted = uikitShouldChangeCharacters(
            oldString: oldString, range: range, string: "-", decimalSeparator: sep
        )
        #expect(accepted, "Oracle should accept replacing negative sign with negative sign")
    }

    @Test(arguments: [".", ","])
    func oracleRejectsAddingSecondNegativeSign(sep: String) {
        let oldString = "-5"
        let range = NSRange(location: 0, length: 0) // insert at beginning without replacing
        let accepted = uikitShouldChangeCharacters(
            oldString: oldString, range: range, string: "-", decimalSeparator: sep
        )
        #expect(!accepted, "Oracle should reject adding second negative sign")
    }

    @Test(arguments: [".", ","])
    func oracleAllowsNegativeSignAtBeginningOfEmptyString(sep: String) {
        let formatter = InputCommandFormatter(decimalSeparator: sep)
        let accepted = uikitShouldChangeCharacters(
            oldString: "", range: NSRange(location: 0, length: 0), string: "-", decimalSeparator: sep
        )
        #expect(accepted)
        #expect(formatter.isValidNumberDraft("-"))
    }

    @Test(arguments: [".", ","])
    func oracleAllowsDecimalSeparatorAfterDigits(sep: String) {
        let formatter = InputCommandFormatter(decimalSeparator: sep)
        let oldString = "3"
        let range = NSRange(location: 1, length: 0)
        let accepted = uikitShouldChangeCharacters(
            oldString: oldString, range: range, string: sep, decimalSeparator: sep
        )
        #expect(accepted)

        let result = "3\(sep)"
        #expect(formatter.isValidNumberDraft(result))
    }

    @Test(arguments: [".", ","])
    func oracleExhaustiveSingleCharInsertions(sep: String) {
        let formatter = InputCommandFormatter(decimalSeparator: sep)
        // Try inserting every test character at every position in a set of
        // valid starting strings. Oracle and isValidNumberDraft must agree.
        let validStarts = ["", "1", "-", "12", "-3", "4\(sep)", "\(sep)5", "-6\(sep)7"]
        let testChars: [String] = ["0", "5", "9", "-", sep, "+", "a"]

        for oldString in validStarts {
            for pos in 0 ... oldString.count {
                for char in testChars {
                    let range = NSRange(location: pos, length: 0)
                    let oracleAccepted = uikitShouldChangeCharacters(
                        oldString: oldString, range: range, string: char, decimalSeparator: sep
                    )
                    let resultString = (oldString as NSString).replacingCharacters(in: range, with: char)
                    let draftValid = formatter.isValidNumberDraft(resultString)

                    #expect(
                        oracleAccepted == draftValid,
                        "Disagreement: \"\(oldString)\" + insert \"\(char)\" @\(pos) → \"\(resultString)\": oracle=\(oracleAccepted), draft=\(draftValid) (sep=\(sep))"
                    )
                }
            }
        }
    }

    @Test(arguments: [".", ","])
    func oracleExhaustiveDeletionsOnShortStrings(sep: String) {
        let formatter = InputCommandFormatter(decimalSeparator: sep)
        // For valid strings, try deleting each single character and verify agreement
        let validStrings = ["1", "12", "-3", "4\(sep)5", "-6\(sep)7", "\(sep)8", "-\(sep)"]

        for oldString in validStrings {
            for pos in 0 ..< oldString.count {
                let range = NSRange(location: pos, length: 1)
                let oracleAccepted = uikitShouldChangeCharacters(
                    oldString: oldString, range: range, string: "", decimalSeparator: sep
                )
                let resultString = (oldString as NSString).replacingCharacters(in: range, with: "")
                let draftValid = formatter.isValidNumberDraft(resultString)

                // Deletions should always be accepted by both
                #expect(
                    oracleAccepted,
                    "Oracle should always accept deletion: \"\(oldString)\" delete @\(pos) → \"\(resultString)\" (sep=\(sep))"
                )
                #expect(
                    draftValid,
                    "isValidNumberDraft should accept deletion result: \"\(oldString)\" delete @\(pos) → \"\(resultString)\" (sep=\(sep))"
                )
            }
        }
    }
}
