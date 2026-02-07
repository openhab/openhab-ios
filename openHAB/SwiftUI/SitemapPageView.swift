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
                    ForEach(Self.placeholderWidgets, id: \.id) { widget in
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
            viewModel.startPageHandling()
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
    /// Lightweight placeholder widgets for skeleton loading state — no dependency on PreviewConstants
    static let placeholderWidgets: [OpenHABWidget] = (0 ..< 6).map { i in
        OpenHABWidget(
            widgetId: "placeholder_\(i)",
            label: "Placeholder [100]",
            icon: "none",
            type: .text,
            url: nil, period: nil, minValue: nil, maxValue: nil, step: nil,
            refresh: nil, height: nil, isLeaf: nil, iconColor: nil,
            labelColor: nil, valueColor: nil, service: nil, state: nil,
            text: nil, legend: nil, inputHint: nil, encoding: nil,
            item: nil, linkedPage: nil, mappings: [], widgets: [],
            visibility: true, switchSupport: nil, forceAsItem: nil,
            labelSource: .unknown, releaseOnly: nil
        )
    }
}

#Preview {
    let previewViewModel = SitemapPageViewModel(
        title: "Preview Page",
        widgets: SitemapPageView.placeholderWidgets
    )
    SitemapPageView(viewModel: previewViewModel)
}
