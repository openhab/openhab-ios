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
    /// How long each number of dots shows while loading.
    nonisolated static let dotInterval: TimeInterval = 0.4

    /// Nil while the entries are read.
    @State private var lines: [String]?
    @State private var exportURL: URL?
    @State private var loadingStarted = Date.now

    let myFont = Font
        .system(size: 10)
        .monospaced()

    public var body: some View {
        ScrollView {
            // One Text per line, laid out as they scroll in: a single Text holding a day of
            // entries takes seconds to lay out.
            LazyVStack(alignment: .leading, spacing: 0) {
                if let lines {
                    ForEach(lines.indices, id: \.self) { index in
                        Text(lines[index])
                            .font(myFont)
                    }
                } else {
                    TimelineView(.periodic(from: loadingStarted, by: Self.dotInterval)) { context in
                        HStack(spacing: 0) {
                            Text("Retrieving logs")
                            Text(verbatim: " " + Self.loadingDots(after: context.date.timeIntervalSince(loadingStarted)))
                        }
                        .font(myFont)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Retrieving logs")
                }
            }
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
            // Reading a day of entries and writing the export takes seconds. A view's task runs
            // on the main actor, so do it in a task of its own to keep the app responsive.
            let (fetched, url) = await Task.detached(priority: .userInitiated) {
                let text = Self.fetchLogs()
                return (text.components(separatedBy: "\n"), Self.makeExportURL(for: text))
            }.value
            lines = fetched
            exportURL = url
        }
    }

    public init() {}

    /// One to five dots, one more each `dotInterval`, then from one again.
    nonisolated static func loadingDots(after elapsed: TimeInterval) -> String {
        let step = max(0, Int(elapsed / dotInterval))
        return String(repeating: ".", count: step % 5 + 1)
    }

    private nonisolated static func modelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { ptr in
            String(bytes: ptr.prefix { $0 != 0 }, encoding: .utf8) ?? "unknown"
        }
    }

    private nonisolated static func makeExportURL(for text: String) -> URL? {
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

    private nonisolated static func fetchLogs() -> String {
        let calendar = Calendar.current
        guard let dayAgo = calendar.date(
            byAdding: .day,
            value: -1,
            to: Date.now
        ) else {
            return "Invalid calendar"
        }

        do {
            let predicate = NSPredicate(format: "(subsystem BEGINSWITH $PREFIX)").withSubstitutionVariables(
                [
                    "PREFIX": "org.openhab"
                ]
            )

            let logs = try Logger.fetch(
                since: dayAgo,
                predicateFormat: predicate.predicateFormat
            )
            return makeLogHeader() + logs.joined()
        } catch {
            return error.localizedDescription
        }
    }

    private nonisolated static func makeLogHeader() -> String {
        let bundle = Bundle.main
        let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let modelIdentifier = Self.modelIdentifier()
        let generated = Date.now.formatted(.logTimestamp)

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
                let dateString = entry.date.formatted(.logTimestamp)
                logs.append("""
                \(dateString): \
                \(log.category):\(log.level.description): \
                \(entry.composedMessage)\n
                """)
            } else {
                logs.append("\(entry.date): \(entry.composedMessage)\n")
            }
        }

        if logs.isEmpty {
            logs = ["Nothing found"]
        }
        return logs
    }
}

#Preview {
    LogsViewer()
}

public extension FormatStyle where Self == Date.ISO8601FormatStyle {
    /// ISO 8601 in local time with its offset and milliseconds, for the entries and the export
    /// header alike: the steps of a load within one second can be told apart, and the time is
    /// unambiguous wherever the log is read.
    static var logTimestamp: Self {
        .init(timeZoneSeparator: .colon, includingFractionalSeconds: true, timeZone: .current)
    }
}
