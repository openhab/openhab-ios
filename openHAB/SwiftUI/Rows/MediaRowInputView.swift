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

struct MediaRowInputView: View {
    let rowID: RowID
    let input: MediaRowInput
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        if let widget = viewModel.widget(for: rowID) {
            switch input.renderingKind {
            case .image, .chart:
                ImageRowView(widget: widget)
            case .video:
                VideoRowView(widget: widget)
            case .webview:
                WidgetWebViewContainer(widget: widget)
            case .mapview:
                MapRowView(widget: widget)
            default:
                GenericRowView(widget: widget)
            }
        } else {
            EmptyView()
        }
    }
}
