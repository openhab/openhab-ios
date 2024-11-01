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
import OSLog
import SwiftUI

struct LogView: View {
    let logs: [OSLogEntryLog]

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
    LogView(logs: .init([]))
}
