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

struct RollershutterRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel
    @State private var triggerUpFeedback = false
    @State private var triggerStopFeedback = false
    @State private var triggerDownFeedback = false

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetRollershutterView")

    var body: some View {
        let displayState = widget.displayState
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                IconView(widget: widget)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    if !displayState.labelText.isEmpty {
                        let labelText = displayState.labelText
                        Text(labelText)
                            .ohTextToken(.rowLabel)
                            .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
                    }
                }

                Spacer()

                Button {
                    triggerUpFeedback.toggle()
                    logger.info("\("up button pressed")")
                    viewModel.sendCommand(RollerShutterCommand.up.rawValue, for: widget)
                } label: {
                    Image(systemSymbol: .chevronUp)
                        .font(.title2)
                        .foregroundStyle(Color(UIColor.systemBlue))
                }
                .buttonStyle(.plain)
                .sensoryHeavyFeedbackIfAvailable(trigger: triggerUpFeedback)

                Button {
                    triggerStopFeedback.toggle()
                    logger.info("\("stop button pressed")")
                    viewModel.sendCommand(RollerShutterCommand.stop.rawValue, for: widget)
                } label: {
                    Image(systemSymbol: .stop)
                        .font(.title2)
                        .foregroundStyle(Color(UIColor.systemBlue))
                }
                .buttonStyle(.plain)
                .sensoryHeavyFeedbackIfAvailable(trigger: triggerStopFeedback)

                Button {
                    triggerDownFeedback.toggle()
                    logger.info("\("down button pressed")")
                    viewModel.sendCommand(RollerShutterCommand.down.rawValue, for: widget)
                } label: {
                    Image(systemSymbol: .chevronDown)
                        .font(.title2)
                        .foregroundStyle(Color(UIColor.systemBlue))
                }
                .buttonStyle(.plain)
                .sensoryHeavyFeedbackIfAvailable(trigger: triggerDownFeedback)
            }
        }
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
        RollershutterRowView(widget: widget)
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
