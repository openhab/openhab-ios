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

struct WidgetRollershutterView: View {
    @ObservedObject var widget: OpenHABWidget

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetRollershutterView")

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(widget.labelText ?? widget.label)
                        .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(UIColor(fromString: widget.labelcolor)))

                    if let labelValue = widget.labelValue, !labelValue.isEmpty {
                        Text(labelValue)
                            .font(.caption)
                            .foregroundColor(widget.valuecolor.isEmpty ? .secondary : Color(UIColor(fromString: widget.valuecolor)))
                    }
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Button(action: {
                    logger.info("up button pressed")
                    widget.sendCommand("UP")
                }) {
                    Image(systemName: "chevron.up")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button(action: {
                    logger.info("stop button pressed")
                    widget.sendCommand("STOP")
                }) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button(action: {
                    logger.info("down button pressed")
                    widget.sendCommand("DOWN")
                }) {
                    Image(systemName: "chevron.down")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
    }
}
