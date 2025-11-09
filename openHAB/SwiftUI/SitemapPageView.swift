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

import CommonUI
import OpenHABCore
import SwiftUI

struct SitemapPageView: View {
    @StateObject public var viewModel = SitemapPageViewModel()

    private var isLinkedPage: Bool {
        viewModel.isLinked
    }

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.relevantWidgets.isEmpty {
                // Show skeleton/placeholder rows while loading
                List(placeholderWidgets, id: \.id) { widget in
                    RowViewFactory.view(for: widget)
                        .redacted(reason: .placeholder)
                        .disabled(true)
                }
                .environment(\.defaultMinListRowHeight, 30)
            } else {
                List(viewModel.relevantWidgets) { widget in
                    EmbeddingRowView(widget: widget)
                }
                .environment(\.defaultMinListRowHeight, 30)
            }
        }
        .environmentObject(viewModel)
        .listStyle(.inset)
        .navigationTitle(viewModel.pageTitle)
        .navigationBarTitleDisplayMode(.inline)
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

extension SitemapPageView {
    /// Creates placeholder widgets for skeleton loading state
    public var placeholderWidgets: [OpenHABWidget] {
        [
            PreviewConstants.openHABSitemapPage!.widgets[3],
            PreviewConstants.openHABSitemapPage!.widgets[5],
            PreviewConstants.openHABSitemapPage!.widgets[2],
            PreviewConstants.openHABSitemapPage!.widgets[6],
            PreviewConstants.openHABSitemapPage!.widgets[17],
            PreviewConstants.openHABSitemapPage!.widgets[4]
        ]
    }
}

#Preview {
    let previewViewModel = SitemapPageViewModel(
        pageUrl: PreviewConstants.openHABSitemapPage?.link ?? "",
        title: PreviewConstants.openHABSitemapPage?.title ?? "Preview Page",
        widgets: SitemapPageView(viewModel: SitemapPageViewModel()).placeholderWidgets
    )
    SitemapPageView(viewModel: previewViewModel)
}
