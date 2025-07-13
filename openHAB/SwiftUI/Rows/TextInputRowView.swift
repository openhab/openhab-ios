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

struct TextInputRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @State private var inputText = ""
    @FocusState private var isTextFieldFocused: Bool

    private let logger = Logger(subsystem: "org.openhab", category: "WidgetTextInputView")

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if IconView.shouldShowIcon(for: widget) {
                IconView(widget: widget)
                    .frame(width: 24, height: 24)
                    .padding(.top, 4) // Align with text
            }

            VStack(alignment: .leading, spacing: 8) {
                if let labelText = widget.labelText, !labelText.isEmpty {
                    Text(labelText)
                        .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
                }

                TextField("Enter text", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        sendTextCommand()
                    }

                if let labelValue = widget.labelValue, !labelValue.isEmpty {
                    Text(labelValue)
                        .font(.caption)
                        .foregroundColor(widget.valuecolor.isEmpty ? .secondary : Color(fromString: widget.valuecolor))
                }
            }
        }
        .onAppear {
            inputText = widget.item?.state ?? ""
        }
        .onChange(of: widget.item?.state) { newState in
            if !isTextFieldFocused {
                inputText = newState ?? ""
            }
        }
    }

    private func sendTextCommand() {
        logger.info("Sending text command: \(inputText)")
        widget.sendCommand(inputText)
        isTextFieldFocused = false
    }
}
