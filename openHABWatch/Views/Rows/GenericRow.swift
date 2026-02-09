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

struct GenericRow: View {
    @ObservedObject var widget: OpenHABWidget
    @ObservedObject var settings = AppSettings.shared
    @State private var viewModel: WidgetRowViewModel

    var body: some View {
        HStack {
            IconView(widget: widget, settings: settings)
            TextLabelView(widget: widget, font: .caption, lineLimit: 2)
            Spacer()
            DetailTextLabelView(widget: widget)
            widget.makeView(settings: settings)
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
    let widget = PreviewWidgetFactory.generic(label: "Unsupported Widget", valueText: "N/A")
    GenericRow(widget: widget)
        .environmentObject(AppSettings())
}
