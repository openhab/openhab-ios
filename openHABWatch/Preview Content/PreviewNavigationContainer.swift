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

import OpenHABCore
import SwiftUI

struct InteractiveStateTokenPreview<Content: View>: View {
    let widget: OpenHABWidget
    let states: [String]
    private let content: (OpenHABWidget, String) -> Content
    @State private var selectedStateIndex = 0

    private var currentToken: String {
        let token = states[safe: selectedStateIndex]
        return token ?? widget.item?.state ?? widget.state
    }

    var body: some View {
        VStack(spacing: 8) {
            content(widget, currentToken)
            Picker("State", selection: $selectedStateIndex) {
                ForEach(0 ..< states.count, id: \.self) { index in
                    Text(states[index]).tag(index)
                }
            }
            .labelsHidden()
            .accessibilityLabel("Preview state")
        }
    }

    init(widget: OpenHABWidget,
         states: [String],
         @ViewBuilder content: @escaping (OpenHABWidget, String) -> Content) {
        self.widget = widget
        self.states = states.isEmpty ? [widget.item?.state ?? widget.state] : states
        self.content = content
    }
}

struct PreviewNavigationContainer<Content: View>: View {
    @State private var settings = AppSettings()
    @State private var userData = UserData(preview: true)
    private let content: Content

    var body: some View {
        NavigationStack {
            content
        }
        .environmentObject(settings)
        .environmentObject(userData)
    }

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
}
