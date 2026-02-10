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
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var settings: AppSettings
    @State private var localIsOn: Bool?
    @State private var viewModel: WidgetRowViewModel
    @State private var commandSender = WidgetCommandSender()

    private var isOn: Bool {
        localIsOn ?? viewModel.isOn
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
                    WatchLabelText(widget: widget)
                    DetailTextLabelView(widget: widget)
                }
            }
        }
        .padding(.trailing)
        .cornerRadius(5)
        .onAppear {
            viewModel.update(from: widget)
        }
        .onChange(of: widget.item?.state, initial: false) { _, _ in
            viewModel.update(from: widget)
        }
        .onChange(of: viewModel.effectiveState) {
            localIsOn = nil
        }
    }

    init(widget: OpenHABWidget) {
        self.widget = widget
        _viewModel = State(wrappedValue: WidgetRowViewModel(widget: widget))
    }
}

#Preview {
    let widget = PreviewWidgetFactory.switchWidget(label: "Outdoor Light", state: "ON")
    PreviewNavigationContainer {
        SwitchRow(widget: widget)
    }
}

#Preview {
    let widget = PreviewWidgetFactory.switchWidget(label: "Outdoor Light", state: "OFF")
    let mockSettings = {
        let obj = AppSettings()
        obj.openHABRootUrl = PreviewConstants.remoteURLString
        return obj
    }()
    NavigationStack {
        SwitchRow(widget: widget)
    }
    .environmentObject(mockSettings)
}
