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
            HStack {
                IconInputView(input: input.icon, rowIdentity: input.widgetId, size: CGSize(width: 32, height: 32))

                VStack(alignment: .leading, spacing: 2) {
                    if !displayState.labelText.isEmpty {
                        let labelText = displayState.labelText
                        Text(labelText)
                            .ohTextToken(.rowLabel)
                            .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))
                    }
                }

                Spacer()

                Button {
                    triggerUpFeedback.toggle()
                    logger.info("\("up button pressed")")
                    onSendCommand(.up)
                } label: {
                    Image(systemSymbol: .chevronUp)
                        .font(.title2)
                        .foregroundStyle(Color(UIColor.systemBlue))
                }
                .buttonStyle(.plain)
                .ohMinimumHitTarget()
                .sensoryHeavyFeedbackIfAvailable(trigger: triggerUpFeedback)

                Button {
                    triggerStopFeedback.toggle()
                    logger.info("\("stop button pressed")")
                    onSendCommand(.stop)
                } label: {
                    Image(systemSymbol: .stop)
                        .font(.title2)
                        .foregroundStyle(Color(UIColor.systemBlue))
                }
                .buttonStyle(.plain)
                .ohMinimumHitTarget()
                .sensoryHeavyFeedbackIfAvailable(trigger: triggerStopFeedback)

                Button {
                    triggerDownFeedback.toggle()
                    logger.info("\("down button pressed")")
                    onSendCommand(.down)
                } label: {
                    Image(systemSymbol: .chevronDown)
                        .font(.title2)
                        .foregroundStyle(Color(UIColor.systemBlue))
                }
                .buttonStyle(.plain)
                .ohMinimumHitTarget()
                .sensoryHeavyFeedbackIfAvailable(trigger: triggerDownFeedback)
            }
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

extension View {
    @ViewBuilder
    func sensoryHeavyFeedbackIfAvailable(trigger: Bool) -> some View {
        if #available(iOS 17.0, *) {
            sensoryFeedback(.impact(weight: .heavy, intensity: 0.9), trigger: trigger)
        } else {
            self
        }
    }

    @ViewBuilder
    func sensoryStopFeedbackIfAvailable(trigger: Bool) -> some View {
        if #available(iOS 17.0, *) {
            sensoryFeedback(.impact(flexibility: .rigid), trigger: trigger)
        } else {
            self
        }
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[5]
    VStack {
        RollershutterRowView(input: RollershutterRowInput.from(widget: widget))
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
