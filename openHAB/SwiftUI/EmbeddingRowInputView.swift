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

import SwiftUI

/// Transitional adapter: drives list from immutable row inputs while reusing existing widget-driven rows.
struct EmbeddingRowInputView: View {
    let rowInput: SitemapRowInput

    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        Group {
            if let widget = viewModel.widget(for: rowInput.rowID) {
                EmbeddingRowView(widget: widget)
            } else {
                EmptyView()
            }
        }
    }
}
