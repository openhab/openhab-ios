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
    @State private var isSearchPresented = false
    @FocusState private var isLegacySearchFocused: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let onShowMenu: () -> Void

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
                if !isCommandLifecycleIdle {
                    ToolbarItem(placement: .navigationBarLeading) {
                        commandLifecycleIndicator
                    }
                }
                if viewModel.showSearchField {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if #available(iOS 17.0, *) {
                            Button {
                                isSearchPresented = true
                            } label: {
                                Image(systemSymbol: .magnifyingglass)
                            }
                            .accessibilityLabel("Search")
                        } else {
                            Button {
                                isSearchPresented = true
                                isLegacySearchFocused = true
                            } label: {
                                Image(systemSymbol: .magnifyingglass)
                            }
                            .accessibilityLabel("Search")
                        }
                    }
                }
                if horizontalSizeClass == .compact {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            onShowMenu()
                        } label: {
                            Image(systemSymbol: .line3Horizontal)
                                .font(.title)
                        }
                    }
                }
            }

        if viewModel.showSearchField {
            if #available(iOS 17.0, *) {
                if isSearchPresented {
                    page
                        .searchable(
                            text: $viewModel.searchText,
                            isPresented: $isSearchPresented,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: Text(NSLocalizedString("search_items", comment: ""))
                        )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    page
                }
            } else {
                page
                    .safeAreaInset(edge: .bottom) {
                        if isSearchPresented {
                            legacySearchBar
                        }
                    }
            }
        } else {
            page
        }
    }

    private var legacySearchBar: some View {
        HStack(spacing: 8) {
            Image(systemSymbol: .magnifyingglass)
                .foregroundStyle(.secondary)
                .font(.footnote)

            TextField(NSLocalizedString("search_items", comment: ""), text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isLegacySearchFocused)
                .font(.footnote)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemSymbol: .xmarkCircleFill)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button {
                isSearchPresented = false
                isLegacySearchFocused = false
            } label: {
                Image(systemSymbol: .xmark)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Color(.secondarySystemBackground).opacity(0.6),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
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

    private var isCommandLifecycleIdle: Bool {
        if case .idle = viewModel.commandLifecycleSummary {
            return true
        }
        return false
    }

    init(viewModel: SitemapPageViewModel, onShowMenu: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onShowMenu = onShowMenu
    }

    init(onShowMenu: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: SitemapPageViewModel())
        self.onShowMenu = onShowMenu
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
