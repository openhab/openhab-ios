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

import OpenHABCore
import OSLog
import SFSafeSymbols
import SwiftUI

struct LogEntry: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let message: String
}

struct LoggerView: View {
    let template = NSPredicate(format: "(subsystem BEGINSWITH $PREFIX)")
    @State private var logs: [LogEntry] = []
    @State private var isLoading = true

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading logs...")
                    .padding()
            } else if logs.isEmpty {
                Text("No logs found")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List(logs, id: \.id) { log in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(formattedDate(log.timestamp))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.gray)

                        Text(log.message)
                            .font(.body)
                    }
                }
                .listStyle(.plain)
            }
        }
        .task {
            if logs.isEmpty { // Prevents overwriting preview logs
                await loadLogs()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(
                    item: shareLogs(),
                    preview: SharePreview("Share Log Data")
                ) {
                    Label("Share", systemSymbol: .squareAndArrowUp)
                }
                .disabled(logs.isEmpty)
            }
        }
    }

    init(logs: [LogEntry] = []) { // Custom initializer for preview
        _logs = State(initialValue: logs)
        _isLoading = State(initialValue: logs.isEmpty) // Set isLoading based on logs
    }

    private func loadLogs() async {
        isLoading = true
        defer { isLoading = false }
        logs = await fetchLogs(with: template)
    }

    func fetchLogs(with template: NSPredicate) async -> [LogEntry] {
        let predicate = template.withSubstitutionVariables(["PREFIX": "org.openhab"])

        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let position = store.position(date: Date().addingTimeInterval(-300)) // Last 300 seconds
            let entries = try store.getEntries(at: position, matching: predicate)

            let logs = entries.compactMap { entry -> LogEntry? in
                guard let logEntry = entry as? OSLogEntryLog else { return nil }
                return LogEntry(timestamp: logEntry.date, message: logEntry.composedMessage)
            }

            return Array(logs.reversed()) // Ensures latest logs appear first
        } catch {
            Logger.settingsView.error("Error fetching logs: \(error.localizedDescription)")
            return []
        }
    }

    // Custom Date Formatting Function
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS" // Hours:Minutes:Seconds.Milliseconds
        return formatter.string(from: date)
    }

    private func shareLogs() -> String {
        logs
            .map { "[\($0.timestamp)] \($0.message)" }
            .joined(separator: "\n")
    }
}

#Preview {
    LoggerView(logs: [
        LogEntry(timestamp: Date(), message: "This is a test log entry."),
        LogEntry(timestamp: Date().addingTimeInterval(-60), message: "Another log entry for preview.")
    ])
}
