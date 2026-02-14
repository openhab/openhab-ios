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
import SFSafeSymbols
import SwiftUI

struct SitemapNavigationView: View {
    @StateObject var viewModel = SitemapPageViewModel()
    let onShowSideMenu: () -> Void

    var body: some View {
        NavigationStack {
            sitemapContent
        }
    }

    @ViewBuilder
    private var sitemapContent: some View {
        let page = SitemapPageView(viewModel: viewModel)
            .navigationTitle(viewModel.pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    commandLifecycleIndicator
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onShowSideMenu()
                    } label: {
                        Image(systemSymbol: .line3Horizontal)
                            .font(.title)
                    }
                }
            }

        if viewModel.showSearchField {
            page
                .searchable(text: $viewModel.searchText, prompt: Text(NSLocalizedString("search_items", comment: "")))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        } else {
            page
        }
    }

    @ViewBuilder
    private var commandLifecycleIndicator: some View {
        switch viewModel.commandLifecycleSummary {
        case .idle:
            EmptyView()
        case .sending:
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Sending command")
        case let .failed(count):
            HStack(spacing: 4) {
                Image(systemSymbol: .exclamationmarkTriangleFill)
                Text("\(count)")
            }
            .foregroundStyle(.red)
            .font(.caption)
            .accessibilityLabel("Command failures: \(count)")
        }
    }

    init(viewModel: SitemapPageViewModel, onShowSideMenu: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onShowSideMenu = onShowSideMenu
    }

    init(onShowSideMenu: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: SitemapPageViewModel())
        self.onShowSideMenu = onShowSideMenu
    }
}

#Preview {
    let previewViewModel = SitemapPageViewModel(
        pageUrl: PreviewConstants.openHABSitemapPage?.link ?? "",
        title: PreviewConstants.openHABSitemapPage?.title ?? "Preview Page"
    )
    SitemapNavigationView(viewModel: previewViewModel) {
        print("Show side menu tapped")
    }
}
