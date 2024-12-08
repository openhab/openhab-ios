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

public class LogService {
    static let shared = Logger()
    private var fileHandle: FileHandle!

    // Return the folder URL, and create the folder if it doesn't exist yet.
    // Return nil to trigger a crash if the folder creation fails.
    //
    private var _folderURL: URL?
    private var folderURL: URL! {
        guard _folderURL == nil else { return _folderURL }

        var folderURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).last!
        folderURL.appendPathComponent("Logs")

        if !FileManager.default.fileExists(atPath: folderURL.path) {
            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            } catch {
                print("Failed to create the log folder: \(folderURL)! \n\(error)")
                return nil // To trigger crash.
            }
        }
        _folderURL = folderURL
        return folderURL
    }

    // Return the file URL, and create the file if it doesn't exist yet.
    // Return nil to trigger a crash if the file creation fails.
    //
    private var _fileURL: URL?
    private var fileURL: URL! {
        guard _fileURL == nil else { return _fileURL }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let dateString = dateFormatter.string(from: Date())

        var fileURL: URL = folderURL
        fileURL.appendPathComponent("\(dateString).log")

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            if !FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil) {
                print("Failed to create the log file: \(fileURL)!")
                return nil // To trigger crash.
            }
        }
        _fileURL = fileURL
        return fileURL
    }

    // Use this dispatch queue to make the log file access thread-safe.
    // Public methods use performBlockAndWait to access the resource; private methods don't.
    //
    private lazy var ioQueue: DispatchQueue = .init(label: "ioQueue")

    public init() {
        fileHandle = try? FileHandle(forUpdating: fileURL)
        assert(fileHandle != nil, "Failed to create the file handle!")
    }

    private func performBlockAndWait<T>(_ block: () -> T) -> T {
        ioQueue.sync {
            block()
        }
    }

    // Get the current log file URL.
    //
    func getFileURL() -> URL {
        performBlockAndWait { fileURL }
    }

    func writeLogs() async {
        let template = NSPredicate(
            format: "(subsystem BEGINSWITH $PREFIX)"
        )

        let logData = await fetchLogs(with: template)

        if let data = logData.data(using: .utf8) {
            performBlockAndWait {
                self.fileHandle.write(data)
            }
        }
    }

    // Read the file content and return it as a string.
    //
    func content() -> String {
        performBlockAndWait {
            fileHandle.seek(toFileOffset: 0) // Read from the very beginning.
            return String(data: fileHandle.availableData, encoding: .utf8) ?? ""
        }
    }

    // Clear all logs. Reset the folder and file URL for later use.
    //
    func clearLogs() {
        performBlockAndWait {
            self.fileHandle.closeFile()
            do {
                try FileManager.default.removeItem(at: self.folderURL)
            } catch {
                print("Failed to clear the log folder!\n\(error)")
            }

            // Create a new file handle.
            //
            self._folderURL = nil
            self._fileURL = nil
            self.fileHandle = try? FileHandle(forUpdating: self.fileURL)
            assert(self.fileHandle != nil, "Failed to create the file handle!")
        }
    }
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
