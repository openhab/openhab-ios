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
        HStack {
            IconView(widget: widget)
                .frame(width: 24, height: 24)

            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
            }

            Spacer()

            if let labelValue = widget.labelValue, !labelValue.isEmpty {
                TextField("Enter text", text: $inputText)
                    .multilineTextAlignment(widget.inputHint == .number ? .trailing : .leading)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        sendTextCommand()
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

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[17]
    VStack {
        TextInputRowView(widget: widget)
        Spacer()
    }
}
