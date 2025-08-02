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

import CommonUI
import OpenHABCore
import os.log
import SwiftUI

struct DatePickerInputRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @State private var selectedDate = Date()
    @EnvironmentObject var viewModel: SitemapPageViewModel

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetDatePickerInputView")

    private var datePickerComponents: DatePickerComponents {
        switch widget.inputHint {
        case .date: .date
        case .time: .hourAndMinute
        case .dateTime: [.date, .hourAndMinute]
        default: [.date, .hourAndMinute]
        }
    }

    private var useWheelStyle: Bool {
        widget.inputHint == .time
    }

    var body: some View {
        HStack {
            IconView(widget: widget)
                .frame(width: 24, height: 24)

            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
            }

            Spacer()

            DatePicker(
                selection: $selectedDate,
                displayedComponents: datePickerComponents
            ) {
                EmptyView()
            }
            .onChange(of: selectedDate) { newDate in
                sendDateCommand(newDate)
            }
            .disabled(widget.readOnly ?? false)
        }
        .onAppear {
            if let state = widget.item?.state, !state.isEmpty {
                selectedDate = parseDate(from: state) ?? Date()
            }
        }
    }

    private func sendDateCommand(_ date: Date) {
        let formatter = DateFormatter()

        switch widget.inputHint {
        case .date:
            formatter.dateFormat = "yyyy-MM-dd"
        case .time:
            formatter.dateFormat = "HH:mm"
        case .dateTime:
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        default:
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        }

        let command = formatter.string(from: date)
        logger.info("Sending date command: \(command)")
        viewModel.sendCommand(widget.item, commandToSend: command)
    }

    private func parseDate(from state: String) -> Date? {
        let formatters = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd",
            "HH:mm"
        ]

        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: state) {
                return date
            }
        }
        return nil
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[13]
    VStack {
        DatePickerInputRowView(widget: widget)
            .padding()
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
