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

struct ColorPickerRow: View {
    @ObservedObject var widget: OpenHABWidget
    @ObservedObject var settings = AppSettings.shared
    @State private var viewModel: WidgetRowViewModel
    var body: some View {
        let uiColor = viewModel.colorState

        return
            VStack(spacing: 0) {
                HStack {
                    IconView(widget: widget, settings: settings)
                    TextLabelView(widget: widget, font: .caption, lineLimit: 2)
                    Spacer()
                }
                HStack {
                    Spacer()
                    IconWithAction(
                        systemSymbol: .chevronDownCircleFill,
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

                    Spacer()

                    IconWithAction(
                        systemSymbol:
                        .chevronUpCircleFill,
                        action: upButtonPressed
                    )
                    Spacer()
                }
            }
            .onAppear {
                viewModel.update(from: widget)
            }
            .onChange(of: widget.item?.state, initial: false) { _, _ in
                viewModel.update(from: widget)
            }
    }

    func upButtonPressed() {
        Logger.rowViews.info("ON button pressed")
        widget.sendCommand("ON")
    }

    func downButtonPressed() {
        Logger.rowViews.info("OFF button pressed")
        widget.sendCommand("OFF")
    }

    init(widget: OpenHABWidget) {
        self.widget = widget
        _viewModel = State(wrappedValue: WidgetRowViewModel(widget: widget))
    }
}

#Preview {
    let widget = UserData(preview: true).widgets[10]
    ColorPickerRow(widget: widget)
        .environmentObject(AppSettings())
}
