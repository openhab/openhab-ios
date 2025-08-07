import Foundation

// MARK: - Model

struct XCStringsFlatCatalog: Codable {
    let version: String
    let sourceLanguage: String
    var strings: [String: Entry]

    struct Entry: Codable {
        var localizations: [String: Localization]

        struct Localization: Codable {
            var stringUnit: StringUnit
        }

        struct StringUnit: Codable {
            var value: String
            var state: String
        }
    }
}

// MARK: - Parser

func parseStringsFile(at url: URL) throws -> [String: String] {
    let contents = try String(contentsOf: url, encoding: .utf8)
    var result: [String: String] = [:]

    let regex = try! Regex(#""(?<key>[^"]+)"\s*=\s*"(?<value>(?:[^"\\]|\\.)*)";"#)

    for line in contents.split(separator: "\n") {
        guard let match = try? regex.wholeMatch(in: String(line)) else { continue }

        let key = String(match.output["key"]!.substring!)
        var value = String(match.output["value"]!.substring!)

        // Unescape common sequences
        value = value
            .replacingOccurrences(of: #"\""#, with: "\"")
            .replacingOccurrences(of: #"\\n"#, with: "\n")

        result[key] = value
    }

    return result
}

// MARK: - Conversion

func convertAllToUnifiedFlatXCStrings(at basePath: URL, sourceLanguage: String = "en") throws {
    let fileManager = FileManager.default
    let contents = try fileManager.contentsOfDirectory(at: basePath, includingPropertiesForKeys: nil)
    let lprojDirs = contents.filter { $0.pathExtension == "lproj" }

    var catalog = XCStringsFlatCatalog(version: "1.0", sourceLanguage: sourceLanguage, strings: [:])

    for lproj in lprojDirs {
        let language = lproj.deletingPathExtension().lastPathComponent
        let stringsFile = lproj.appendingPathComponent("Localizable.strings")

        guard fileManager.fileExists(atPath: stringsFile.path) else {
            print("⚠️ Skipping \(language) — no Localizable.strings found")
            continue
        }

        let entries = try parseStringsFile(at: stringsFile)

        for (key, value) in entries {
            let stringUnit = XCStringsFlatCatalog.Entry.StringUnit(value: value, state: "translated")
            let localization = XCStringsFlatCatalog.Entry.Localization(stringUnit: stringUnit)

            if catalog.strings[key] == nil {
                catalog.strings[key] = .init(localizations: [:])
            }
            catalog.strings[key]?.localizations[language] = localization
        }
    }

    // Output unified .xcstrings flat file
    let outputURL = basePath.appendingPathComponent("Localizable.xcstrings")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(catalog)
    try data.write(to: outputURL)

    print("✅ Wrote unified catalog to \(outputURL.path)")
}

// MARK: - Main

do {
    let basePath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    try convertAllToUnifiedFlatXCStrings(at: basePath)
} catch {
    print("❌ Error: \(error.localizedDescription)")
}
