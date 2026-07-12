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
import UIKit

struct SitemapPageView: View {
    @StateObject var viewModel = SitemapPageViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var idleTimerDisabled = false
    @State private var scrollPosition = ScrollPosition()
    @State private var showScrollToTop = false
    @State private var gridLayoutCache = SitemapGridLayoutCache()
    /// Sub-pages are created while the app is already active, so the first .active transition they
    /// observe is a genuine return from background — don't skip it. Root pages start false to skip
    /// the launch-time .active that races the initial .task startup.
    @State private var hasSeenActivePhase: Bool

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
                GeometryReader { proxy in
                    pageContent(width: proxy.size.width)
                }
                .scrollPosition($scrollPosition)
                .onScrollGeometryChange(for: Bool.self) { geo in
                    geo.contentOffset.y > 150
                } action: { _, isScrolledDown in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showScrollToTop = Preferences.shared.hideStatusBar && isScrolledDown
                    }
                }
                .onChange(of: viewModel.pageId) {
                    scrollPosition.scrollTo(edge: .top)
                }
                .overlay(alignment: .bottomTrailing) {
                    if showScrollToTop {
                        Button {
                            withAnimation {
                                scrollPosition.scrollTo(edge: .top)
                            }
                        } label: {
                            Image(systemSymbol: .arrowUp)
                                .font(.system(size: 16, weight: .semibold))
                                .padding(12)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding([.trailing, .bottom], 16)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                guard hasSeenActivePhase else {
                    hasSeenActivePhase = true
                    return
                }
                viewModel.refreshOnForeground()
            }
        }
        .navigationTitle(viewModel.pageTitle)
        .navigationBarTitleDisplayMode(.large)
        .alert("Error", isPresented: Binding(
            get: { viewModel.error != nil && !(viewModel.error is SitemapPageError) },
            set: { if !$0 { Task { @MainActor in viewModel.error = nil } } }
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
        _hasSeenActivePhase = State(initialValue: viewModel.isLinked)
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
            .listRowBackground(Color(UIColor.ohSecondarySystemGroupedBackground))
        }
    }

    private var listContent: some View {
        List(viewModel.rowInputs) { rowInput in
            rowContent(rowInput)
                .listRowInsets(RowLayoutPolicy.rowInsets(for: rowInput))
                .listRowBackground(RowLayoutPolicy.rowBackground(for: rowInput))
        }
    }

    private func pageContent(width: CGFloat) -> some View {
        let columnCount = SitemapPresentationPolicy.columnCount(
            for: width,
            horizontalSizeClass: horizontalSizeClass
        )

        return Group {
            if width <= 0 {
                Color.clear
            } else if columnCount > 1 {
                gridContent(columnCount: columnCount)
            } else {
                listContent
            }
        }
    }

    private func gridContent(columnCount: Int) -> some View {
        let rowInputs = viewModel.rowInputs
        let layout = gridLayoutCache.layout(
            for: rowInputs,
            version: viewModel.rowInputLayoutVersion
        )

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: SitemapPresentationPolicy.gridSpacing) {
                ForEach(layout.sections) { section in
                    if let headerIndex = section.headerIndex,
                       let header = rowInputs[safe: headerIndex] {
                        gridFrameRow(header)
                    }

                    ForEach(section.groups) { group in
                        switch group.content {
                        case let .regular(rowIndices):
                            LazyVGrid(
                                columns: SitemapPresentationPolicy.columns(count: columnCount),
                                alignment: .leading,
                                spacing: SitemapPresentationPolicy.gridSpacing
                            ) {
                                ForEach(rowIndices, id: \.self) { rowIndex in
                                    if let rowInput = rowInputs[safe: rowIndex] {
                                        gridCell(rowInput)
                                    }
                                }
                            }
                        case let .fullWidth(rowIndex):
                            if let rowInput = rowInputs[safe: rowIndex] {
                                gridFullWidthCell(rowInput)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, SitemapPresentationPolicy.gridHorizontalPadding)
            .padding(.vertical, SitemapPresentationPolicy.gridVerticalPadding)
        }
        .background(Color(UIColor.ohSystemGroupedBackground))
    }

    private func gridFrameRow(_ rowInput: SitemapRowInput) -> some View {
        rowContent(rowInput)
            .padding(RowLayoutPolicy.rowInsets(for: rowInput))
            .frame(maxWidth: .infinity, alignment: .center)
            .background(RowLayoutPolicy.rowBackground(for: rowInput))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(UIColor.separator).opacity(0.5))
                    .frame(height: SitemapPresentationPolicy.gridFrameSeparatorHeight)
            }
    }

    private func gridFullWidthCell(_ rowInput: SitemapRowInput) -> some View {
        rowContent(rowInput)
            .padding(RowLayoutPolicy.rowInsets(for: rowInput))
            .padding(.trailing, rowInput.showsGridNavigationAffordance ? 12 : 0)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .center)
            .background(RowLayoutPolicy.rowBackground(for: rowInput))
            .overlay(alignment: .trailing) {
                if rowInput.showsGridNavigationAffordance {
                    Image(systemSymbol: .chevronRight)
                        .foregroundStyle(.tertiary)
                        .ohTextToken(.secondary)
                        .padding(.trailing, 10)
                }
            }
    }

    private func gridCell(_ rowInput: SitemapRowInput) -> some View {
        rowContent(rowInput)
            .padding(RowLayoutPolicy.rowInsets(for: rowInput))
            .padding(.trailing, rowInput.showsGridNavigationAffordance ? 12 : 0)
            .frame(
                maxWidth: .infinity,
                minHeight: 32,
                alignment: .center
            )
            .frame(height: SitemapPresentationPolicy.cellHeight(for: rowInput), alignment: .center)
            .background(RowLayoutPolicy.rowBackground(for: rowInput))
            .overlay(alignment: .trailing) {
                if rowInput.showsGridNavigationAffordance {
                    Image(systemSymbol: .chevronRight)
                        .foregroundStyle(.tertiary)
                        .ohTextToken(.secondary)
                        .padding(.trailing, 10)
                }
            }
    }

    private func rowContent(_ rowInput: SitemapRowInput) -> some View {
        EmbeddingRowInputView(rowInput: rowInput)
            .equatable()
    }
}

#Preview {
    let previewViewModel = SitemapPageViewModel(
        title: "Preview Page",
        widgets: []
    )
    SitemapPageView(viewModel: previewViewModel)
}
