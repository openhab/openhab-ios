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

struct SitemapPageView: View {
    @StateObject public var viewModel = SitemapPageViewModel()

    var body: some View {
        List(viewModel.relevantWidgets) { widget in
            WidgetViewFactory.view(for: widget)
                .onTapGesture {
                    viewModel.widgetTapped(widget)
                }
        }
        .navigationTitle(viewModel.pageTitle)
        .searchable(text: $viewModel.searchText)
        .refreshable {
            await viewModel.reload()
        }
        .task {
            viewModel.startPageHandling()
        }
        .onChange(of: viewModel.networkTracker.activeConnection) { activeConnection in
            viewModel.handleActiveConnectionChange(activeConnection)
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil), actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        })
    }

    init(viewModel: SitemapPageViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
}
