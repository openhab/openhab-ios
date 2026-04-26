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
import os.log
import SwiftUI

struct ImageRawRow: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var settings: AppSettings
    @State private var viewModel: WidgetRowViewModel

    var body: some View {
        Group {
            if let data = viewModel.effectiveState.components(separatedBy: ",")[safe: 1],
               let decodedData = Data(base64Encoded: data, options: .ignoreUnknownCharacters),
               let image = UIImage(data: decodedData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        }
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
    let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg=="
    let widget = PreviewWidgetFactory.imageRaw(label: "Camera", base64: base64)
    PreviewNavigationContainer {
        ImageRawRow(widget: widget)
    }
}
