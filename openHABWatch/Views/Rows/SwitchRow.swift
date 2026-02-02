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
import SwiftUI

struct SwitchRow: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var settings: AppSettings
    @State private var localIsOn: Bool?

    private var effectiveState: String {
        var state = widget.state
        if state.isEmpty {
            state = widget.item?.state ?? ""
        }
        return state
    }

    private var isOn: Bool {
        localIsOn ?? effectiveState.parseAsBool()
    }

    var body: some View {
        Toggle(isOn: Binding(
            get: { isOn },
            set: { newValue in
                localIsOn = newValue
                if newValue {
                    Logger.rowViews.info("Switch to ON")
                    widget.sendCommand("ON")
                } else {
                    Logger.rowViews.info("Switch to OFF")
                    widget.sendCommand("OFF")
                }
            }
        )) {
            HStack {
                IconView(widget: widget, settings: settings)
                VStack {
                    TextLabelView(widget: widget, lineLimit: 1)
                    DetailTextLabelView(widget: widget)
                }
            }
        }
        .padding(.trailing)
        .cornerRadius(5)
        .onChange(of: effectiveState) { _ in
            localIsOn = nil
        }
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
