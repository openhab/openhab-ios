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
import OSLog
import SFSafeSymbols
import SwiftUI

// Thanks to https://useyourloaf.com/blog/fetching-oslog-messages-in-swift/

public struct LogsViewer: View {
    private static let template = NSPredicate(format:
        "(subsystem BEGINSWITH $PREFIX)")

    @State private var text = String(localized: "Loading…")
    @State private var exportURL: URL?

    let myFont = Font
        .system(size: 10)
        .monospaced()

    public var body: some View {
        ScrollView {
            Text(text)
                .font(myFont)
                .padding()
        }
        .navigationTitle("Logs")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Image(systemSymbol: .squareAndArrowUp)
                    }
                    .accessibilityLabel("Share Logs")
                }
            }
        }
        .task {
            text = fetchLogs()
            exportURL = makeExportURL(for: text)
        }
    }

    public init() {}

    private static func modelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { ptr in
            String(bytes: ptr.prefix { $0 != 0 }, encoding: .utf8) ?? "unknown"
        }
    }

    private func makeExportURL(for text: String) -> URL? {
        let fileName = "openhab-logs-\(Date.now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)))"
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension("log")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private func fetchLogs() -> String {
        let calendar = Calendar.current
        guard let dayAgo = calendar.date(
            byAdding: .day,
            value: -1,
            to: Date.now
        ) else {
            return "Invalid calendar"
        }

        do {
            let predicate = Self.template.withSubstitutionVariables(
                [
                    "PREFIX": "org.openhab"
                ])

            let logs = try Logger.fetch(
                since: dayAgo,
                predicateFormat: predicate.predicateFormat
            )
            return makeLogHeader() + logs.joined()
        } catch {
            return error.localizedDescription
        }
    }

    private func makeLogHeader() -> String {
        let bundle = Bundle.main
        let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let modelIdentifier = Self.modelIdentifier()
        let generated = Date.now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))

        return """
        openHAB iOS \(appVersion) (\(buildNumber))
        \(osVersion) — \(modelIdentifier)
        Generated: \(generated)
        \(String(repeating: "-", count: 60))
        """
    }
}

private extension OSLogEntryLog.Level {
    var description: String {
        switch self {
        case .undefined: "undefined"
        case .debug: "debug"
        case .info: "info"
        case .notice: "notice"
        case .error: "error"
        case .fault: "fault"
        @unknown default: "default"
        }
    }
}

public extension Logger {
    static func fetch(since date: Date,
                      predicateFormat: String) throws -> [String] {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let position = store.position(date: date)
        let predicate = NSPredicate(format: predicateFormat)
        let entries = try store.getEntries(
            at: position,
            matching: predicate
        )

        var logs: [String] = []
        for entry in entries {
            try Task.checkCancellation()
            if let log = entry as? OSLogEntryLog {
                let dateString = entry.date.formatted(
                    .dateTime
                        .year()
                        .month(.twoDigits)
                        .day(.twoDigits)
                        .hour(.twoDigits(amPM: .omitted))
                        .minute(.twoDigits)
                        .second(.twoDigits)
                        .locale(Locale(identifier: "en_US_POSIX"))
                )
                var attributedMessage = AttributedString(dateString)
                attributedMessage.font = .headline

                logs.append("""
                \(dateString): \
                \(log.category):\(log.level.description): \
                \(entry.composedMessage)\n
                """)
            } else {
                logs.append("\(entry.date): \(entry.composedMessage)\n")
            }
        }

        if logs.isEmpty { logs = ["Nothing found"] }
        return logs
    }
}

#Preview {
    LogsViewer()
}
