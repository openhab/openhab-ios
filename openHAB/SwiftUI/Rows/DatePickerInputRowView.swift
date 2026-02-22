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

import CommonUI
import OpenHABCore
import os.log
import SwiftUI

private struct DateInputRowConfig {
    let input: InputRowInput
    let onSendCommand: (String) -> Void
}

@MainActor
private func makeDateInputRowContent(_ config: DateInputRowConfig) -> DateInputRowContent {
    DateInputRowContent(
        input: config.input,
        iconInput: config.input.icon,
        inputHint: config.input.inputHint
    ) { command in
        config.onSendCommand(command)
    }
}

private struct DateInputRowContent: View {
    let input: InputRowInput
    let iconInput: RowIconInput
    let inputHint: OpenHABWidget.InputHint
    let onSendCommand: (String) -> Void

    @State private var selectedDate = Date()

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetDatePickerInputView")

    private var datePickerComponents: DatePickerComponents {
        switch inputHint {
        case .date: .date
        case .time: .hourAndMinute
        case .dateTime: [.date, .hourAndMinute]
        default: [.date, .hourAndMinute]
        }
    }

    var body: some View {
        let displayState = input.displayState
        HStack {
            IconInputView(input: iconInput, rowIdentity: input.widgetId, size: CGSize(width: 32, height: 32))

            if !displayState.labelText.isEmpty {
                let labelText = displayState.labelText
                Text(labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))
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
            .disabled(input.readOnly)
        }
        .onAppear {
            let state = displayState.effectiveState
            if !state.isEmpty {
                selectedDate = parseDate(from: state) ?? Date()
            }
        }
    }

    private func sendDateCommand(_ date: Date) {
        let formatter = DateFormatter()

        switch inputHint {
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
        onSendCommand(command)
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

struct DatePickerInputRowView: View {
    let input: InputRowInput
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        makeDateInputRowContent(
            DateInputRowConfig(
                input: input) { command in
                    guard let itemName = input.itemName else { return }
                    viewModel.sendCommand(command, for: itemName)
                    // swiftlint:disable:next closure_end_indentation
                }
        )
    }
}

#if DEBUG
#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[13]
    VStack {
        DatePickerInputRowView(input: InputRowInput.from(widget: widget))
            .padding()
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
#endif
