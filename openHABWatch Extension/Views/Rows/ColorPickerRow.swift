// Copyright (c) 2010-2020 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import os.log
import SwiftUI

struct ColorPickerRow: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    @ObservedObject var settings = ObservableOpenHABDataObject.shared
    var body: some View {
        let uiColor = widget.item?.stateAsUIColor()

        return
            VStack(spacing: 0) {
                HStack {
                    IconView(widget: widget, settings: settings)
                    TextLabelView(widget: widget)
                    Spacer()
                }
                HStack {
                    Spacer()
                    EncircledIconWithAction(
                        systemName: "chevron.down.circle.fill",
                        action: self.downButtonPressed
                    )

                    Spacer()

                    NavigationLink(destination: ColorSelection()) {
                        Circle()
                            .fill(Color(uiColor!))
                            .frame(width: 35, height: 35)
                    }

                    Spacer()

                    EncircledIconWithAction(
                        systemName: "chevron.up.circle.fill",
                        action: self.upButtonPressed
                    )
                    Spacer()
                }
            }
    }

    func upButtonPressed() {
        os_log("ON button pressed", log: .command, type: .info)
        widget.sendCommand("ON")
    }

    func downButtonPressed() {
        os_log("OFF button pressed", log: .command, type: .info)
        widget.sendCommand("OFF")
    }
}

struct ColorRow_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[10]
        return ColorPickerRow(widget: widget)
    }
}
