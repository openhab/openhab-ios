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
import SFSafeSymbols
import SwiftUI

struct RollershutterRow: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var settings: AppSettings
    @State private var viewModel: WidgetRowViewModel

    var body: some View {
        VStack(spacing: -5) {
            HStack {
                IconView(widget: widget, settings: settings)
                TextLabelView(widget: widget, font: .caption, lineLimit: 2)
                Spacer()
            }
            HStack {
                Spacer()
                IconWithAction(systemSymbol: .chevronUpCircleFill) {
                    widget.sendCommand("UP")
                }
                Spacer()
                IconWithAction(systemSymbol: .square) {
                    widget.sendCommand("STOP")
                }
                Spacer()

                IconWithAction(systemSymbol: .chevronDownCircleFill) {
                    widget.sendCommand("DOWN")
                }
                Spacer()
            }
            .frame(height: 50)
        }
        .accessibilityLabel(viewModel.labelText)
        .onAppear {
            viewModel.update(from: widget)
        }
        .onChange(of: widget.item?.state, initial: false) { _, _ in
            viewModel.update(from: widget)
        }
    }

    init(widget: OpenHABWidget) {
        self.widget = widget
        _viewModel = State(wrappedValue: WidgetRowViewModel(widget: widget))
    }
}

#Preview {
    let widget = UserData(preview: true).widgets[5]
    RollershutterRow(widget: widget)
        .environmentObject(AppSettings())
}
