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
import os.log
import SwiftUI

struct WidgetDatePickerInputView: View {
    @ObservedObject var widget: OpenHABWidget
    @State private var selectedDate = Date()

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetDatePickerInputView")

    private var datePickerComponents: DatePickerComponents {
        switch widget.inputHint {
        case .date: .date
        case .time: .hourAndMinute
        case .datetime: [.date, .hourAndMinute]
        default: [.date, .hourAndMinute]
        }
    }

    private var useWheelStyle: Bool {
        widget.inputHint == .time
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(UIColor(fromString: widget.labelcolor)))
            }

            DatePicker(
                selection: $selectedDate,
                displayedComponents: datePickerComponents
            ) {
                EmptyView()
            }
//        if useWheelStyle {
//            .datePickerStyle(.wheel)
//        } else {
//            .datePickerStyle(.compact)
//        }
            .onChange(of: selectedDate) { newDate in
                sendDateCommand(newDate)
            }

            if let labelValue = widget.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .font(.caption)
                    .foregroundColor(widget.valuecolor.isEmpty ? .secondary : Color(UIColor(fromString: widget.valuecolor)))
            }
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
        case .datetime:
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        default:
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        }

        let command = formatter.string(from: date)
        logger.info("Sending date command: \(command)")
        widget.sendCommand(command)
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
