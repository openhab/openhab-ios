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
import UIKit

struct SitemapPageView: View {
    @StateObject var viewModel = SitemapPageViewModel()
    @State private var idleTimerDisabled = false

    private var isLinkedPage: Bool {
        viewModel.isLinked
    }

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.rowInputs.isEmpty {
                if isLinkedPage {
                    // Linked page: structure unknown until poll returns — show a plain spinner
                    // rather than a skeleton that implies known structure.
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Root page: show skeleton/placeholder rows while loading
                    List {
                        ForEach(0 ..< 6, id: \.self) { _ in
                            PlaceholderRowView()
                                .redacted(reason: .placeholder)
                                .disabled(true)
                        }
                    }
                }
            } else {
                List(viewModel.rowInputs) { rowInput in
                    EmbeddingRowInputView(rowInput: rowInput)
                }
            }
        }
        .environmentObject(viewModel)
        .listStyle(.plain)
        .listRowSpacing(0)
        .environment(\.defaultMinListRowHeight, 32)
        .refreshable {
            await viewModel.reload()
            viewModel.startPageHandling(forceRestart: true, reason: "pull-to-refresh")
        }
        .task {
            viewModel.startPageHandling()
        }
        .onAppear {
            viewModel.markAppeared()
            // Disable idle timer if configured in settings
            if Preferences.shared.idleOff {
                UIApplication.shared.isIdleTimerDisabled = true
                idleTimerDisabled = true
            }
        }
        .onDisappear {
            viewModel.stopPageHandling()
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
                    .ohTextToken(.secondary)
            }
        })
    }

    init(viewModel: SitemapPageViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
}

extension SitemapPageView {
    private struct PlaceholderRowView: View {
        var body: some View {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 160, height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 90, height: 12)
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
    }
}

#Preview {
    let previewViewModel = SitemapPageViewModel(
        title: "Preview Page",
        widgets: []
    )
    SitemapPageView(viewModel: previewViewModel)
}
