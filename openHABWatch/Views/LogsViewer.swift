// Copyright (c) 2010-2025 Contributors to the openHAB project
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
import SwiftUI

// Thanks to https://useyourloaf.com/blog/fetching-oslog-messages-in-swift/

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
                      predicateFormat: String) async throws -> [String] {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let position = store.position(date: date)
        let predicate = NSPredicate(format: predicateFormat)
        let entries = try store.getEntries(
            at: position,
            matching: predicate
        )

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var logs: [String] = []
        for entry in entries {
            try Task.checkCancellation()
            if let log = entry as? OSLogEntryLog {
                var attributedMessage = AttributedString(dateFormatter.string(from: entry.date))
                attributedMessage.font = .headline

                logs.append("""
                \(dateFormatter.string(from: entry.date)): \
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

struct LogsViewer: View {
    @State private var text = "Loading..."

    private static let template = NSPredicate(format:
        "(subsystem BEGINSWITH $PREFIX)")

    let myFont = Font
        .system(size: 10)
        .monospaced()

    private func fetchLogs() async -> String {
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

            let logs = try await Logger.fetch(
                since: dayAgo,
                predicateFormat: predicate.predicateFormat
            )
            return logs.joined()
        } catch {
            return error.localizedDescription
        }
    }

    var body: some View {
        ScrollView {
            Text(text)
                .font(myFont)
                .padding()
        }
        .task {
            text = await fetchLogs()
        }
    }
}

#Preview {
    LogsViewer()
}
