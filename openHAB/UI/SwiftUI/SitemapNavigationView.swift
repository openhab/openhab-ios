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
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var viewModel = SitemapPageViewModel()
    @State private var hasSeenActivePhase = false
    @State private var isSearchPresented = false
    @FocusState private var isLegacySearchFocused: Bool
    let onShowSideMenu: () -> Void

    var body: some View {
        NavigationStack {
            sitemapContent
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                // Skip only the first activation to avoid racing the initial .task startup.
                guard hasSeenActivePhase else {
                    hasSeenActivePhase = true
                    return
                }
                viewModel.refreshOnForeground()
            default:
                break
            }
        }
    }

    @ViewBuilder
    private var sitemapContent: some View {
        let page = SitemapPageView(viewModel: viewModel)
            .navigationTitle(viewModel.pageTitle)
            .navigationBarTitleDisplayMode(.automatic)
            .toolbar {
                if !isInteractionIdle {
                    ToolbarItem(placement: .navigationBarLeading) {
                        interactionIndicator
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
                            .ohMinimumHitTarget()
                            .accessibilityLabel("Search")
                        } else {
                            Button {
                                isSearchPresented = true
                                isLegacySearchFocused = true
                            } label: {
                                Image(systemSymbol: .magnifyingglass)
                            }
                            .ohMinimumHitTarget()
                            .accessibilityLabel("Search")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onShowSideMenu()
                    } label: {
                        Image(systemSymbol: .line3Horizontal)
                            .font(.title)
                    }
                    .ohMinimumHitTarget()
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
                            prompt: Text(String(localized: "search_items", comment: ""))
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
                .ohTextToken(.secondary)

            TextField(String(localized: "search_items", comment: ""), text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isLegacySearchFocused)
                .ohTextToken(.secondary)

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
    private var interactionIndicator: some View {
        switch viewModel.sitemapInteractionSummary {
        case .onlineIdle:
            EmptyView()
        case .connecting:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("Connecting")
                    .ohTextToken(.secondary)
            }
            .foregroundStyle(.secondary)
            .accessibilityLabel("Connecting")
        case .offline:
            HStack(spacing: 4) {
                Image(systemSymbol: .wifiExclamationmark)
                Text("Offline")
                    .ohTextToken(.secondary)
            }
            .foregroundStyle(.secondary)
            .accessibilityLabel("Offline")
        case let .queued(count):
            HStack(spacing: 4) {
                Image(systemSymbol: .clock)
                if count > 1 {
                    Text("\(count)")
                        .ohTextToken(.secondary)
                }
            }
            .foregroundStyle(.secondary)
            .accessibilityLabel("Queued commands: \(count)")
        case let .sending(count):
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                if count > 1 {
                    Text("\(count)")
                        .ohTextToken(.secondary)
                }
            }
            .accessibilityLabel("Sending commands: \(count)")
        case let .failed(count):
            HStack(spacing: 4) {
                Image(systemSymbol: .exclamationmarkTriangleFill)
                Text("\(count)")
            }
            .foregroundStyle(.red)
            .ohTextToken(.secondary)
            .accessibilityLabel("Command failures: \(count)")
        }
    }

    private var isInteractionIdle: Bool {
        if case .onlineIdle = viewModel.sitemapInteractionSummary {
            return true
        }
        return false
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

#if DEBUG
#Preview {
    let previewViewModel = SitemapPageViewModel(
        pageUrl: PreviewConstants.openHABSitemapPage?.link ?? "",
        title: PreviewConstants.openHABSitemapPage?.title ?? "Preview Page"
    )
    SitemapNavigationView(viewModel: previewViewModel) {
        print("Show side menu tapped")
    }
}
#endif
