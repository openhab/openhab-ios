// Copyright (c) 2010-2024 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import SwiftUI

struct RollershutterRow: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    var body: some View {
        VStack(spacing: -5) {
            HStack {
                IconView(widget: widget, settings: settings)
                TextLabelView(widget: widget)
                Spacer()
            }
            HStack {
                Spacer()

                EncircledIconWithAction(systemSymbol: .chevronUpCircleFill) {
                    widget.sendCommand("UP")
                }

                Spacer()

                EncircledIconWithAction(systemSymbol: .square) {
                    widget.sendCommand("STOP")
                }

                Spacer()

                EncircledIconWithAction(systemSymbol: .chevronDownCircleFill) {
                    widget.sendCommand("DOWN")
                }

                Spacer()
            }
            .frame(height: 50)
        }
    }
}

struct Rollershutter_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[5]
        return RollershutterRow(widget: widget)
    }
}
