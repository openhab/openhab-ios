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

struct SitemapPageView: View {
    @StateObject var viewModel = SitemapPageViewModel()
    @State private var idleTimerDisabled = false

    private var isLinkedPage: Bool {
        viewModel.isLinked
    }

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.relevantWidgets.isEmpty {
                // Show skeleton/placeholder rows while loading
                List {
                    // Redacted large title header
                    if viewModel.pageTitle.isEmpty {
                        Text("Placeholder Title")
                            .font(.largeTitle.bold())
                            .redacted(reason: .placeholder)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    ForEach(placeholderWidgets, id: \.id) { widget in
                        EmbeddingRowView(widget: widget)
                            .redacted(reason: .placeholder)
                            .disabled(true)
                    }
                }
            } else {
                List(viewModel.relevantWidgets) { widget in
                    EmbeddingRowView(widget: widget)
                }
            }
        }
        .environmentObject(viewModel)
        .listStyle(.plain)
        .listRowSpacing(0)
        .environment(\.defaultMinListRowHeight, 32)
        .refreshable {
            await viewModel.reload()
        }
        .task {
            // Linked pages start loading when the view appears (after navigation).
            // The root page is handled by the for-await connection observer in init().
            if viewModel.isLinked {
                viewModel.startPageHandling()
            }
        }
        .onAppear {
            // Disable idle timer if configured in settings
            if Preferences.shared.idleOff {
                UIApplication.shared.isIdleTimerDisabled = true
                idleTimerDisabled = true
            }
        }
        .onDisappear {
            // Re-enable idle timer when leaving the view
            if idleTimerDisabled {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
        .navigationTitle(viewModel.pageTitle)
        .navigationBarTitleDisplayMode(.large)
        .alert("Error", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        ), actions: {
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
    var placeholderWidgets: [OpenHABWidget] {
        guard let page = PreviewConstants.openHABSitemapPage else { return [] }
        return [
            page.widgets[safe: 3],
            page.widgets[safe: 5],
            page.widgets[safe: 2],
            page.widgets[safe: 6],
            page.widgets[safe: 17],
            page.widgets[safe: 4]
        ].compactMap(\.self)
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
