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
import SFSafeSymbols
import SwiftUI

enum RollerShutterCommand: String {
    case up = "UP"
    case down = "DOWN"
    case stop = "STOP"
}

private struct RollershutterRowConfig {
    let input: RollershutterRowInput
    let viewModel: SitemapPageViewModel
    let triggerUpFeedback: Binding<Bool>
    let triggerStopFeedback: Binding<Bool>
    let triggerDownFeedback: Binding<Bool>
}

@MainActor
private func makeRollershutterRowContent(_ config: RollershutterRowConfig) -> RollershutterRowContent {
    RollershutterRowContent(
        input: config.input,
        triggerUpFeedback: config.triggerUpFeedback,
        triggerStopFeedback: config.triggerStopFeedback,
        triggerDownFeedback: config.triggerDownFeedback
    ) { command in
        guard let itemName = config.input.itemName else { return }
        config.viewModel.sendCommand(command.rawValue, for: itemName)
    }
}

private struct RollershutterRowContent: View {
    let input: RollershutterRowInput
    @Binding var triggerUpFeedback: Bool
    @Binding var triggerStopFeedback: Bool
    @Binding var triggerDownFeedback: Bool
    let onSendCommand: (RollerShutterCommand) -> Void

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetRollershutterView")

    var body: some View {
        let displayState = input.displayState
        VStack(alignment: .leading, spacing: 8) {
            RowViewWithIcon(input: input) {
                VStack(alignment: .leading, spacing: 2) {
                    if !displayState.labelText.isEmpty {
                        let labelText = displayState.labelText
                        Text(labelText)
                            .ohTextToken(.rowLabel)
                            .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))
                    }
                }

                Spacer(minLength: 8)

                if let value = displayState.labelValue {
                    Text(value)
                        .ohTextToken(.rowValue)
                        .foregroundStyle(input.valueColor.isEmpty ? .secondary : Color(fromString: input.valueColor))
                }

                Button {
                    triggerDownFeedback.toggle()
                    logger.info("down button pressed")
                    onSendCommand(.down)
                } label: {
                    Image(systemSymbol: .arrowtriangleDownCircle)
                        .font(.title2)
                        .foregroundStyle(Color(UIColor.systemBlue))
                }
                .buttonStyle(.plain)
                .sensoryHeavyFeedbackIfAvailable(trigger: triggerDownFeedback)

                Button {
                    triggerStopFeedback.toggle()
                    logger.info("stop button pressed")
                    onSendCommand(.stop)
                } label: {
                    Image(systemSymbol: .stopCircle)
                        .font(.title2)
                        .foregroundStyle(Color(UIColor.systemBlue))
                }
                .buttonStyle(.plain)
                .sensoryStopFeedbackIfAvailable(trigger: triggerStopFeedback)

                Button {
                    triggerUpFeedback.toggle()
                    logger.info("up button pressed")
                    onSendCommand(.up)
                } label: {
                    Image(systemSymbol: .arrowtriangleUpCircle)
                        .font(.title2)
                        .foregroundStyle(Color(UIColor.systemBlue))
                }
                .buttonStyle(.plain)
                .sensoryHeavyFeedbackIfAvailable(trigger: triggerUpFeedback)
            }
            .padding(.trailing, -2)
        }
    }
}

struct RollershutterRowView: View {
    let input: RollershutterRowInput
    @EnvironmentObject var viewModel: SitemapPageViewModel
    @State private var triggerUpFeedback = false
    @State private var triggerStopFeedback = false
    @State private var triggerDownFeedback = false

    var body: some View {
        makeRollershutterRowContent(
            RollershutterRowConfig(
                input: input,
                viewModel: viewModel,
                triggerUpFeedback: $triggerUpFeedback,
                triggerStopFeedback: $triggerStopFeedback,
                triggerDownFeedback: $triggerDownFeedback
            )
        )
    }
}

#if DEBUG
#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[5]
    VStack {
        RollershutterRowView(input: RollershutterRowInput.from(widget: widget))
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
#endif
