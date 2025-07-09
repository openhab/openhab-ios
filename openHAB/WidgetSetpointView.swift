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

import OpenHABCore
import SwiftUI

struct WidgetSetpointView: View {
    @ObservedObject var widget: OpenHABWidget

    var body: some View {
        Toggle(isOn: Binding(
            get: {
                widget.state.uppercased() == "ON"
            },
            set: { newValue in
                let newState = newValue ? "ON" : "OFF"
                widget.state = newState // 1. Update local state immediately
                widget.sendCommand(newState) // 2. Send to server
            }
        )) {
            Text(widget.labelText ?? widget.label)
        }
    }
}
