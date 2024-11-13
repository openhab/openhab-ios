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

import CoreTransferable
import OSLog

// Thanks to https://useyourloaf.com/blog/fetching-oslog-messages-in-swift/

// swiftlint:disable:next file_types_order
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

        let entries = try store
            .getEntries(
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
                \(entry.date.formatted(.iso8601)): \
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

public protocol LogServiceProtocol {
    func fetchLogs(with template: NSPredicate) async -> String
}

public struct LogService {
    public init() {}
}

extension LogService: LogServiceProtocol {
    public func fetchLogs(with template: NSPredicate) async -> String {
        let calendar = Calendar.current
        guard let hourAgo = calendar.date(
            byAdding: .hour,
            value: -1,
            to: Date.now
        ) else {
            return "Invalid calendar"
        }

        do {
            let predicate = template.withSubstitutionVariables(
                [
                    "PREFIX": "org.openhab"
                ])

            let logs = try await Logger.fetch(
                since: hourAgo,
                predicateFormat: predicate.predicateFormat
            )
            return logs.joined()
        } catch {
            return error.localizedDescription
        }
    }
}

// extension LogService: Transferable {
//
//    static var containerUrl = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents", isDirectory: true)
//
//    public static var transferRepresentation: some TransferRepresentation {
//        FileRepresentation(exportedContentType: .commaSeparatedText) { csvFile in
//            SentTransferredFile(csvFile.url)
//        }
//    }
// }
