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

import Foundation
import OpenHABCore
import OSLog
import SwiftUI

// swiftlint:disable:next file_types_order
struct LogsViewer: View {
    let template = NSPredicate(
        format: "(subsystem BEGINSWITH $PREFIX)"
    )
    let myFont = Font
        .system(size: 10)
        .monospaced()

    var logService: LogServiceProtocol

    var body: some View {
        List {
            Text(text)
                .font(myFont)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(
                    item: text,
                    preview: SharePreview("Logs", image: Image(.openHABIcon))
                ) {
                    Label("Share Logs", systemSymbol: .squareAndArrowUp)
                }
            }
        }
        .navigationTitle("Logs")
        .task {
            text = await logService.fetchLogs(with: template)
        }
    }

    @State private var text = "Loading..."
}

#if DEBUG
struct MockLogService: LogServiceProtocol {
    func fetchLogs(with template: NSPredicate) async -> String {
        """
        Mocked Data
        Test data
        """
    }
}
#endif

#Preview {
    LogsViewer(logService: MockLogService())
}
