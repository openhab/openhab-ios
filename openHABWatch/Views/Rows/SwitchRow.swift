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
import SwiftUI

struct SwitchRow: View {
    let widget: OpenHABWidget
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pageData: UserData
    let stateToken: String
    @State private var localIsOn: Bool?
    @State private var commandSender = WidgetCommandDispatcher()

    private var isOn: Bool {
        localIsOn ?? stateToken.parseAsBool()
    }

    var body: some View {
        Toggle(isOn: Binding(
            get: { isOn },
            set: { newValue in
                localIsOn = newValue
                if newValue {
                    commandSender.send("ON", for: widget, policy: .immediate)
                } else {
                    commandSender.send("OFF", for: widget, policy: .immediate)
                }
            }
        )) {
            HStack {
                WatchIconView(model: widget.iconRenderModel(), settings: settings)
                VStack {
                    WatchLabelText(text: widget.labelText, labelColor: widget.labelcolor)
                    DetailTextLabelView(text: widget.labelValue, valueColor: widget.valuecolor)
                }
            }
        }
        .padding(.trailing)
        .cornerRadius(5)
        .disabled(widget.item?.readOnly == true)
        .accessibilityValue(isOn ? "On" : "Off")
        .onChange(of: stateToken) {
            localIsOn = nil
        }
        .onAppear {
            commandSender.confirmationHandler = { message, proceed in
                pageData.pendingCommandConfirmation = PendingCommandConfirmation(message: message, onConfirm: proceed)
            }
        }
    }
}

#Preview {
    let widget = PreviewWidgetFactory.switchWidget(label: "Outdoor Light", state: "ON")
    PreviewNavigationContainer {
        SwitchRow(widget: widget, stateToken: widget.item?.state ?? "OFF")
    }
}

#Preview {
    let widget = PreviewWidgetFactory.switchWidget(label: "Outdoor Light", state: "OFF")
    let previewRootURL = "http://192.168.2.10:8080"
    let mockSettings = {
        let obj = AppSettings()
        obj.openHABRootUrl = previewRootURL
        return obj
    }()
    NavigationStack {
        SwitchRow(widget: widget, stateToken: widget.item?.state ?? "OFF")
    }
    .environmentObject(mockSettings)
}
