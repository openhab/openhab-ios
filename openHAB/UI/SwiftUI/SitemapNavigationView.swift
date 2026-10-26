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

// MARK: - Navigation state

enum SitemapNavigationState: Equatable {
    case loading
    case ready([LinkedPageNavigation])

    var navigationPath: [LinkedPageNavigation] {
        if case let .ready(path) = self {
            return path
        }
        return []
    }
}

// MARK: - Native UISearchBar wrapper for iOS 26 (reliable bottom placement)

@available(iOS 26.0, *)
private struct NativeSearchBar: UIViewRepresentable {
    final class Coordinator: NSObject, UISearchBarDelegate {
        var parent: NativeSearchBar

        init(_ parent: NativeSearchBar) {
            self.parent = parent
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            parent.text = searchText
        }

        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            parent.text = ""
            parent.isPresented = false
            searchBar.resignFirstResponder()
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
        }
    }

    @Binding var text: String
    @Binding var isPresented: Bool
    var placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UISearchBar {
        let bar = UISearchBar()
        bar.searchBarStyle = .minimal
        bar.placeholder = placeholder
        bar.autocorrectionType = .no
        bar.autocapitalizationType = .none
        bar.showsCancelButton = true
        bar.delegate = context.coordinator
        bar.becomeFirstResponder()
        return bar
    }

    func updateUIView(_ uiView: UISearchBar, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
}

struct SitemapNavigationView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var viewModel = SitemapPageViewModel()
    @State private var hasSeenActivePhase = false
    @State private var isSearchPresented = false

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            sitemapContent
                .navigationDestination(for: LinkedPageNavigation.self) { nav in
                    SitemapPageView(viewModel: SitemapPageViewModel(pageUrl: nav.pageLink, title: nav.pageTitle))
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
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
                            .padding(6)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                if viewModel.showSearchField {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            isSearchPresented = true
                        } label: {
                            Image(systemSymbol: .magnifyingglass)
                        }
                        .accessibilityLabel("Search")
                    }
                }
            }

        if #available(iOS 26.0, *) {
            // iOS 26: always apply safeAreaInset so SitemapPageView stays in the same
            // structural branch regardless of showSearchField — preventing .onDisappear
            // from firing and cancelling the active page-handling task when the setting
            // changes. The inset is empty when search is not active.
            page
                .safeAreaInset(edge: .bottom) {
                    if viewModel.showSearchField, isSearchPresented {
                        NativeSearchBar(
                            text: $viewModel.searchText,
                            isPresented: $isSearchPresented,
                            placeholder: String(localized: "search_items", comment: "")
                        )
                        .frame(height: 56)
                    }
                }
        } else if viewModel.showSearchField {
            // iOS 17–25: native .searchable at the top
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

    init(viewModel: SitemapPageViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    init(sitemapName: String, navigationPath: [LinkedPageNavigation] = []) {
        _viewModel = StateObject(wrappedValue: SitemapPageViewModel(sitemapName: sitemapName, initialNavigationPath: navigationPath))
    }

    init() {
        _viewModel = StateObject(wrappedValue: SitemapPageViewModel())
    }
}

#if DEBUG
#Preview {
    let previewViewModel = SitemapPageViewModel(
        pageUrl: PreviewConstants.openHABSitemapPage?.link ?? "",
        title: PreviewConstants.openHABSitemapPage?.title ?? "Preview Page"
    )
    SitemapNavigationView(viewModel: previewViewModel)
}
#endif
