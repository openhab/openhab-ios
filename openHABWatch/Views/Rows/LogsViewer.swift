//
//  LogView.swift
//  openHABWatch
//
//  Created by Tim Müller-Seydlitz on 31.10.24.
//  Copyright © 2024 openHAB e.V. All rights reserved.
//

import Foundation
import OSLog
import SwiftUI

struct LogsViewer: View {
    let logs: [OSLogEntryLog]

    init() {
        let logStore = try! OSLogStore(scope: .currentProcessIdentifier)
        self.logs = try! logStore.getEntries().compactMap { entry in
            guard let logEntry = entry as? OSLogEntryLog,
                  logEntry.subsystem.starts(with: "com.donnywals") == true else {
                return nil
            }

            return logEntry
        }
    }

    var body: some View {
        List(logs, id: \.self) { log in
            VStack(alignment: .leading) {
                Text(log.composedMessage)
                HStack {
                    Text(log.subsystem)
                    Text(log.date, format: .dateTime)
                }.bold()
            }
        }
    }
}

#Preview {
    LogsViewer()
}
