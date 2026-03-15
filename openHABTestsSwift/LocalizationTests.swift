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

@testable import openHAB

import Foundation
import Testing

struct LocalizationTests {
    private static var localizations: [String] {
        Bundle.main.localizations.filter { $0 != "Base" }
    }

    // MARK: - Tests

    @Test func infoPlistLocalizations() {
        let mandatoryKeys = ["NSLocalNetworkUsageDescription"]

        for language in LocalizationTests.localizations {
            print("Testing language: '\(language)'.")
            if let path = Bundle.main.paths(forResourcesOfType: "strings", inDirectory: "\(language).lproj").first(where: { $0.contains("InfoPlist.strings") }),
               let dictionary = NSDictionary(contentsOfFile: path) as? [String: String] {
                for key in mandatoryKeys {
                    #expect(dictionary[key] != nil, "Missing entry '\(key)' in InfoPlist.strings for language '\(language)'.")
                    #expect(dictionary[key]?.isEmpty == false, "Missing value for '\(key)' in InfoPlist.strings for language '\(language)'.")
                    print("\(key) = \(dictionary[key] ?? "MISSING")")
                }
            }
        }
    }

    @Test func intentsLocalizations() {
        guard let path = Bundle.main.url(forResource: "Intents", withExtension: "strings", subdirectory: nil, localization: "en"),
              let localizableStrings = NSDictionary(contentsOf: path) as? [String: String],
              !localizableStrings.isEmpty
        else {
            Issue.record("Failed to load Intents.strings.")
            return
        }

        for language in LocalizationTests.localizations {
            print("Testing language: '\(language)'.")

            for localizableString in localizableStrings {
                let translation = localizableString.key.localized(for: language, with: "Intents")
                #expect(translation != nil, "Failed to get translation for key '\(localizableString.key)' in language '\(language)'.")
                #expect(translation != "__MISSING__", "Missing translation for key '\(localizableString.key)' in language '\(language)'.")
                #expect(translation?.isEmpty == false, "Translation for key '\(localizableString.key)' in language '\(language)' is empty.")
                print("Translation: \(localizableString.key) = \(translation ?? "FAILED")")
            }
        }
    }

    @Test func intentsPlaceholders() {
        let regex = #/\$\{([a-z0-9]*)\}/#.ignoresCase()

        guard let path = Bundle.main.url(forResource: "Intents", withExtension: "strings", subdirectory: nil, localization: "en"),
              let placeholderTuples = (NSDictionary(contentsOf: path) as? [String: String])?.filter({ $0.value.contains("${") }),
              !placeholderTuples.isEmpty
        else {
            Issue.record("Failed to load Intents.strings.")
            return
        }

        for language in LocalizationTests.localizations {
            print("Testing language: '\(language)'.")

            guard let path = Bundle.main.url(forResource: "Intents", withExtension: "strings", subdirectory: nil, localization: language),
                  let languageTuples = (NSDictionary(contentsOf: path) as? [String: String])?.filter({ $0.value.contains("${") }),
                  !languageTuples.isEmpty
            else {
                Issue.record("Failed to load Intents.strings for language '\(language)'.")
                continue
            }

            #expect(placeholderTuples.count == languageTuples.count, "Number of strings with placeholders in language '\(language)' doesn't match. Translations to check: \(languageTuples.filter { !placeholderTuples.keys.contains($0.key) }).")

            for placeholderTuple in placeholderTuples {
                let placeholderString = placeholderTuple.value
                guard let translation = placeholderTuple.key.localized(for: language, with: "Intents") else {
                    continue
                }

                let numberOfOccurrencesInPlaceholder = placeholderString.matches(of: regex).count
                let numberOfOccurrencesInTranslation = translation.matches(of: regex).count
                #expect(numberOfOccurrencesInPlaceholder == numberOfOccurrencesInTranslation, "Number of placeholders for key '\(placeholderTuple.key)' in language '\(language)' does not match.")

                let matchesPlaceholder = placeholderString.matches(of: regex).map { String($0.0) }
                let matchesTranslation = translation.matches(of: regex).map { String($0.0) }
                #expect(matchesPlaceholder.elementsEqual(matchesTranslation), "Placeholders do not match for key '\(placeholderTuple.key)' in language '\(language)'.")
                print("Placeholders: \(matchesPlaceholder) == \(matchesTranslation)")
            }
        }
    }
}

private extension String {
    func localized(for language: String, with table: String? = nil) -> String? {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj") else {
            return nil
        }

        return Bundle(path: path)?.localizedString(forKey: self, value: "__MISSING__", table: table)
    }

}
