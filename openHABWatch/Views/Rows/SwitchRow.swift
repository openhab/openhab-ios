// Copyright (c) 2010-2023 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Kingfisher
import OpenHABCore
import os.log
import SwiftUI

struct SwitchRow: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    var body: some View {
        // https://stackoverflow.com/questions/59395501/do-something-when-toggle-state-changes
        let stateBinding = Binding<Bool>(
            get: {
                widget.stateEnumBinding.boolState
            },
            set: {
                if $0 {
                    os_log("Switch to ON", log: .viewCycle, type: .info)
                    widget.sendCommand("ON")
                } else {
                    os_log("Switch to OFF", log: .viewCycle, type: .info)
                    widget.sendCommand("OFF")
                }
                widget.stateEnumBinding = .switcher($0)
            }
        )

        return
            Toggle(isOn: stateBinding) {
                HStack {
                    IconView(widget: widget, settings: settings)
                    VStack {
                        TextLabelView(widget: widget)
                        DetailTextLabelView(widget: widget)
                    }
                }
            }
            .focusable(true)
            .padding(.trailing)
            .cornerRadius(5)
    }
}

struct SwitchRow_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[2]
        return SwitchRow(widget: widget)
            .previewLayout(.fixed(width: 300, height: 70))
    }
}
