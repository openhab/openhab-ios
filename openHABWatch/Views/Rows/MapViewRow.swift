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

struct MapViewRow: View {
    @ObservedObject var widget: OpenHABWidget
    @State private var viewModel: WidgetRowViewModel

    var body: some View {
        VStack {
            MapView(widget: widget)
                .scaledToFit()
                .padding()
            // .frame(height: 300)
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
    let widget = PreviewWidgetFactory.mapview(label: "Location", state: "51.5074,0.1278")
    PreviewNavigationContainer {
        MapViewRow(widget: widget)
    }
}
