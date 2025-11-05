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

struct SwitchRow: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var settings: AppSettings

    // https://stackoverflow.com/questions/59395501/do-something-when-toggle-state-changes
    var stateBinding: Binding<Bool> {
        .init(
            get: { widget.stateEnumBinding.boolState },
            set: {
                if $0 {
                    Logger.rowViews.info("Switch to ON")
                    widget.sendCommand("ON")
                } else {
                    Logger.rowViews.info("Switch to OFF")
                    widget.sendCommand("OFF")
                }
                widget.stateEnumBinding = .switcher($0)
            }
        )
    }

    var body: some View {
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

#Preview {
    let widget = UserData(preview: true).widgets[2]
    SwitchRow(widget: widget)
        .environmentObject(AppSettings())
}

#Preview {
    let widget = UserData(preview: true).widgets[2]
    let mockSettings = {
        let obj = AppSettings()
        obj.openHABRootUrl = PreviewConstants.remoteURLString
        return obj
    }()
    SwitchRow(widget: widget)
        .environmentObject(mockSettings)
}
