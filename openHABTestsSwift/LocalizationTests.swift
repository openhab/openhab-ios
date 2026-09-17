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
import Testing

private final class BundleLocator: AnyObject {}

struct LocalizationTests {
    private struct StringCatalog: Decodable {
        struct Entry: Decodable {
            let comment: String?
            let localizations: [String: Localization]?
            let shouldTranslate: Bool?
        }

        struct Localization: Decodable {
            let stringUnit: StringUnit?
        }

        struct StringUnit: Decodable {
            let state: String
            let value: String
        }

        let sourceLanguage: String
        let strings: [String: Entry]
    }

    private static var localizations: [String] {
        Bundle.main.localizations.filter { $0 != "Base" }
    }

    private static var stringCatalogURL: URL? {
        // Primary: bundle resource (avoids #filePath sandbox restrictions in iOS Simulator)
        if let url = Bundle(for: BundleLocator.self)
            .url(forResource: "LocalizableTestCatalog", withExtension: "json") {
            return url
        }
        // Fallback: source-relative path
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("openHAB/Supporting Files/Localizable.xcstrings")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private static var stringCatalog: StringCatalog? {
        guard let url = stringCatalogURL,
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(StringCatalog.self, from: data)
    }

    private static var appIntentEntries: [String: StringCatalog.Entry] {
        guard let stringCatalog else {
            return [:]
        }

        return stringCatalog.strings.filter { key, entry in
            key.contains("${") || (entry.comment?.localizedCaseInsensitiveContains("app intent") == true)
        }
    }

    private static func sourceValue(for key: String, entry: StringCatalog.Entry, sourceLanguage: String) -> String {
        entry.localizations?[sourceLanguage]?.stringUnit?.value.nonEmpty ?? key
    }

    private static func translatedValue(for language: String, entry: StringCatalog.Entry) -> String? {
        guard let localization = entry.localizations?[language]?.stringUnit else {
            return nil
        }

        return localization.state == "translated" ? localization.value.nonEmpty : nil
    }

    private static func placeholders(in value: String) -> [String] {
        let regex = #/\$\{([a-z0-9]*)\}/#.ignoresCase()
        return value.matches(of: regex).map { String($0.0) }
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
        guard let stringCatalog = LocalizationTests.stringCatalog,
              !LocalizationTests.appIntentEntries.isEmpty
        else {
            Issue.record("Failed to load App Intents entries from Localizable.xcstrings.")
            return
        }

        for (key, entry) in LocalizationTests.appIntentEntries {
            let sourceValue = LocalizationTests.sourceValue(for: key, entry: entry, sourceLanguage: stringCatalog.sourceLanguage)
            #expect(sourceValue.isEmpty == false, "Missing source localization for App Intents key '\(key)'.")

            for language in LocalizationTests.localizations where language != stringCatalog.sourceLanguage {
                guard let translation = LocalizationTests.translatedValue(for: language, entry: entry) else {
                    continue
                }

                #expect(translation.isEmpty == false, "Translation for key '\(key)' in language '\(language)' is empty.")
                print("Translation: \(key) [\(language)] = \(translation)")
            }
        }
    }

    @Test func intentsPlaceholders() {
        guard let stringCatalog = LocalizationTests.stringCatalog
        else {
            Issue.record("Failed to load Localizable.xcstrings.")
            return
        }

        let placeholderEntries = LocalizationTests.appIntentEntries.filter { key, entry in
            LocalizationTests.sourceValue(for: key, entry: entry, sourceLanguage: stringCatalog.sourceLanguage).contains("${")
        }

        guard !placeholderEntries.isEmpty else {
            Issue.record("Failed to load App Intents placeholder entries from Localizable.xcstrings.")
            return
        }

        for (key, entry) in placeholderEntries {
            let sourcePlaceholders = LocalizationTests.placeholders(
                in: LocalizationTests.sourceValue(for: key, entry: entry, sourceLanguage: stringCatalog.sourceLanguage)
            )

            #expect(sourcePlaceholders.isEmpty == false, "Missing placeholders in source string for key '\(key)'.")

            for language in LocalizationTests.localizations where language != stringCatalog.sourceLanguage {
                guard let translation = LocalizationTests.translatedValue(for: language, entry: entry) else {
                    continue
                }

                let translatedPlaceholders = LocalizationTests.placeholders(in: translation)
                #expect(
                    sourcePlaceholders.elementsEqual(translatedPlaceholders),
                    "Placeholders do not match for key '\(key)' in language '\(language)'."
                )
                print("Placeholders: \(sourcePlaceholders) == \(translatedPlaceholders)")
            }
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
