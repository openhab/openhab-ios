// Copyright (c) 2010-2024 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

@testable import openHAB

import Foundation
import XCTest

class LocalizationTests: XCTestCase {
    private static var localizations: [String] {
        Bundle.main.localizations.filter { $0 != "Base" }
    }

    private static let falsePositives: [String] = []

    private static let localizedFormatStrings: [(key: String, arguments: [CVarArg])] = [
        (key: "unable_to_decode_certificate", arguments: ["CERTIFICATE_PLACEHOLDER"]),
        (key: "unable_to_add_certificate", arguments: ["CERTIFICATE_PLACEHOLDER"]),
        (key: "ssl_certificate_invalid", arguments: ["PRESENTER", "SITE"]),
        (key: "ssl_certificate_no_match", arguments: ["PRESENTER", "SITE"])
    ]

    func testFormatStrings() {
        guard validateFormatStringsCompleteness() else {
            XCTFail("'LocalizationTests.localizedFormatStrings' are incomplete.")
            return
        }

        for language in LocalizationTests.localizations {
            print("Testing language: '\(language)'.")
            for tuple in LocalizationTests.localizedFormatStrings {
                guard let translation = tuple.key.localized(for: language)?.replacingOccurrences(of: "%%", with: "") else {
                    XCTFail("Failed to get translation for key '\(tuple.key)' in language '\(language)'.")
                    continue
                }
                XCTAssertNotEqual(translation, "__MISSING__", "Missing translation for key '\(tuple.key)' in language '\(language)'.")
                // swiftlint:disable:next opening_brace
                let regex = /%(?:\d+\$)?[+-]?(?:[lh]{0,2})(?:[qLztj])?(?:[ 0]|'.{1})?\d*(?:\\.\d?)?[@dDiuUxXoOfeEgGcCsSpaAFn]/
                let numberOfMatches = translation.matches(of: regex).count
                XCTAssertEqual(numberOfMatches, tuple.arguments.count, "Invalid number of format specifiers for key '\(tuple.key)' in language '\(language)'.")

                let translationResult = tuple.key.localizedWithFormat(for: language, arguments: tuple.arguments)
                XCTAssertNotNil(translationResult, "Failed to get translation for key '\(tuple.key)' in language '\(language)'.")
                print("Translation: \(tuple.key) = \(translation)")
            }
        }
    }

    func testLocalizations() {
        guard let path = Bundle.main.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: "en"),
              let localizableStrings = NSDictionary(contentsOf: path) as? [String: String],
              !localizableStrings.isEmpty
        else {
            XCTFail("Failed to load bundle.")
            return
        }

        for language in LocalizationTests.localizations {
            print("Testing language: '\(language)'.")

            for localizableString in localizableStrings {
                let translation = localizableString.key.localized(for: language)
                XCTAssertNotNil(translation, "Failed to get translation for key '\(localizableString.key)' in language '\(language)'.")
                XCTAssertNotEqual(translation, "__MISSING__", "Missing translation for key '\(localizableString.key)' in language '\(language)'.")
                XCTAssertFalse(translation?.isEmpty ?? true, "Translation for key '\(localizableString.key)' in language '\(language)' is empty.")
                print("Translation: \(localizableString.key) = \(translation ?? "FAILED")")
            }
        }
    }

    func testInfoPlistLocalizations() {
        let mandatoryKeys = ["NSLocalNetworkUsageDescription"]

        for language in LocalizationTests.localizations {
            print("Testing language: '\(language)'.")
            if let path = Bundle.main.paths(forResourcesOfType: "strings", inDirectory: "\(language).lproj").first(where: { $0.contains("InfoPlist.strings") }),
               let dictionary = NSDictionary(contentsOfFile: path) as? [String: String] {
                for key in mandatoryKeys {
                    XCTAssertNotNil(dictionary[key], "Missing entry '\(key)' in InfoPlist.strings for language '\(language)'.")
                    XCTAssertTrue(dictionary[key]?.isEmpty == false, "Missing value for '\(key)' in InfoPlist.strings for language '\(language)'.")
                    print("\(key) = \(dictionary[key] ?? "MISSING")")
                }
            }
        }
    }

    func testIntentsLocalizations() {
        guard let path = Bundle.main.url(forResource: "Intents", withExtension: "strings", subdirectory: nil, localization: "en"),
              let localizableStrings = NSDictionary(contentsOf: path) as? [String: String],
              !localizableStrings.isEmpty
        else {
            XCTFail("Failed to load bundle.")
            return
        }

        for language in LocalizationTests.localizations {
            print("Testing language: '\(language)'.")

            for localizableString in localizableStrings {
                let translation = localizableString.key.localized(for: language, with: "Intents")
                XCTAssertNotNil(translation, "Failed to get translation for key '\(localizableString.key)' in language '\(language)'.")
                XCTAssertNotEqual(translation, "__MISSING__", "Missing translation for key '\(localizableString.key)' in language '\(language)'.")
                XCTAssertFalse(translation?.isEmpty ?? true, "Translation for key '\(localizableString.key)' in language '\(language)' is empty.")
                print("Translation: \(localizableString.key) = \(translation ?? "FAILED")")
            }
        }
    }

    func testIntentsPlaceholders() {
        guard let path = Bundle.main.url(forResource: "Intents", withExtension: "strings", subdirectory: nil, localization: "en"),
              let placeholderTuples = (NSDictionary(contentsOf: path) as? [String: String])?.filter({ $0.value.contains("${") }),
              !placeholderTuples.isEmpty,
              let regex = try? NSRegularExpression(pattern: "\\$\\{([a-z0-9]*)\\}", options: .caseInsensitive)
        else {
            XCTFail("Failed to load bundle.")
            return
        }

        for language in LocalizationTests.localizations {
            print("Testing language: '\(language)'.")

            guard let path = Bundle.main.url(forResource: "Intents", withExtension: "strings", subdirectory: nil, localization: language),
                  let languageTuples = (NSDictionary(contentsOf: path) as? [String: String])?.filter({ $0.value.contains("${") }),
                  !languageTuples.isEmpty
            else {
                XCTFail("Failed to load Intents.strings for language '\(language)'.")
                continue
            }

            XCTAssertEqual(placeholderTuples.count, languageTuples.count, "Number of strings with placeholders in language '\(language)' doesn't match. Translations to check: \(languageTuples.filter { !placeholderTuples.keys.contains($0.key) }).")

            for placeholderTuple in placeholderTuples {
                let placeholderString = placeholderTuple.value
                guard let translation = placeholderTuple.key.localized(for: language, with: "Intents") else {
                    continue
                }

                let numberOfOccurrencesInPlaceholder = regex.numberOfMatches(in: placeholderString, range: NSRange(placeholderString.startIndex..., in: placeholderString))
                let numberOfOccurrencesInTranslation = regex.numberOfMatches(in: translation, range: NSRange(translation.startIndex..., in: translation))
                XCTAssertEqual(numberOfOccurrencesInPlaceholder, numberOfOccurrencesInTranslation, "Number of placeholders for key '\(placeholderTuple.key)' in language '\(language)' does not match.")

                let matchesPlaceholder = regex.matches(in: placeholderString, options: [], range: NSRange(location: 0, length: placeholderString.utf16.count)).compactMap { Range($0.range, in: placeholderString).map { String(placeholderString[$0]) } }
                let matchesTranslation = regex.matches(in: translation, options: [], range: NSRange(location: 0, length: translation.utf16.count)).compactMap { Range($0.range, in: translation).map { String(translation[$0]) } }
                XCTAssertTrue(matchesPlaceholder.elementsEqual(matchesTranslation), "Placeholders do not match for key '\(placeholderTuple.key)' in language '\(language)'.")
                print("Placeholders: \(matchesPlaceholder) == \(matchesTranslation)")
            }
        }
    }

    private func validateFormatStringsCompleteness() -> Bool {
        guard let path = Bundle.main.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: "en"),
              let localizableStrings = (NSDictionary(contentsOf: path) as? [String: String])?.filter({ !LocalizationTests.falsePositives.contains($0.key) }),
              !localizableStrings.isEmpty
        else {
            XCTFail("Failed to load bundle.")
            return false
        }

        var retVal = true
        for localizableString in localizableStrings where localizableString.value.range(of: "%") != nil {
            guard !LocalizationTests.localizedFormatStrings.contains(where: { $0.key == localizableString.key }) else { continue }

            retVal = false
            XCTFail("Missing translation with key '\(localizableString.key)' in 'LocalizationTests.localizedFormatStrings'.")
        }

        return retVal
    }
}

private extension String {
    func localized(for language: String, with table: String? = nil) -> String? {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj") else {
            return nil
        }

        return Bundle(path: path)?.localizedString(forKey: self, value: "__MISSING__", table: table)
    }

    func localizedWithFormat(for language: String, arguments: [CVarArg]) -> String? {
        if let string = localized(for: language) {
            return String(format: string, arguments: arguments)
        }

        return nil
    }

    subscript(bounds: CountableClosedRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start ... end])
    }

    subscript(bounds: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start ..< end])
    }
}
