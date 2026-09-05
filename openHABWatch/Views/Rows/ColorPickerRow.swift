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
internal import SFSafeSymbols
import SwiftUI

struct ColorPickerRow: View {
    let widget: OpenHABWidget
    let stateToken: String
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pageData: UserData
    @State private var viewModel: WidgetRowViewModel
    @State private var commandSender = WidgetCommandDispatcher()
    var body: some View {
        let uiColor = viewModel.colorState

        return
            VStack(spacing: 0) {
                HStack {
                    WatchIconView(model: widget.iconRenderModel(), settings: settings)
                    WatchLabelText(text: viewModel.labelText)
                    Spacer()
                }
                HStack {
                    Spacer()
                    IconWithAction(
                        systemSymbol: .chevronDownCircleFill,
                        accessibilityLabel: "Decrease brightness",
                        action: downButtonPressed
                    )

                    Spacer()

                    NavigationLink(destination: ColorSelection(widget: widget)) {
                        Circle()
                            .fill(uiColor.map { Color($0) } ?? Color.gray.opacity(0.4))
                            .frame(width: 35, height: 35)
                            .overlay {
                                if uiColor == nil {
                                    Circle()
                                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                }
                            }
                    }
                    .accessibilityLabel("Select color")

                    Spacer()

                    IconWithAction(
                        systemSymbol:
                        .chevronUpCircleFill,
                        accessibilityLabel: "Increase brightness",
                        action: upButtonPressed
                    )
                    Spacer()
                }
            }
            .onChange(of: stateToken, initial: false) { _, _ in
                viewModel.update(from: widget)
            }
            .onAppear {
                commandSender.confirmationHandler = { message, proceed in
                    pageData.pendingCommandConfirmation = PendingCommandConfirmation(message: message, onConfirm: proceed)
                }
            }
    }

    init(widget: OpenHABWidget) {
        self.widget = widget
        stateToken = widget.item?.state ?? widget.state
        _viewModel = State(wrappedValue: WidgetRowViewModel(widget: widget))
    }

    init(widget: OpenHABWidget, stateToken: String) {
        self.widget = widget
        self.stateToken = stateToken
        _viewModel = State(wrappedValue: WidgetRowViewModel(widget: widget))
    }

    func upButtonPressed() {
        commandSender.send("ON", for: widget, policy: .immediate)
    }

    func downButtonPressed() {
        commandSender.send("OFF", for: widget, policy: .immediate)
    }
}

#Preview {
    let widget = PreviewWidgetFactory.colorpicker(
        label: "Color",
        state: "120,100,100",
        icon: "colorwheel"
    )
    PreviewNavigationContainer {
        ColorPickerRow(widget: widget, stateToken: widget.item?.state ?? widget.state)
    }
}

#Preview("Interactive State Token") {
    let widget = PreviewWidgetFactory.colorpicker(
        label: "Color",
        state: "120,100,100",
        icon: "colorwheel"
    )
    PreviewNavigationContainer {
        InteractiveStateTokenPreview(
            widget: widget,
            states: ["0,100,100", "120,100,100", "240,100,100", "NULL"]
        ) { targetWidget, stateToken in
            ColorPickerRow(widget: targetWidget, stateToken: stateToken)
        }
    }
}
