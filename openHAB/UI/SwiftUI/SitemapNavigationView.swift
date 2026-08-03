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

// MARK: - Environment key for side-menu action

private struct SitemapSideMenuKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var sitemapSideMenuAction: (() -> Void)? {
        get { self[SitemapSideMenuKey.self] }
        set { self[SitemapSideMenuKey.self] = newValue }
    }
}

// MARK: - Native UISearchBar wrapper for iOS 26 (reliable bottom placement)

@available(iOS 26.0, *)
private struct NativeSearchBar: UIViewRepresentable {
    @Binding var text: String
    @Binding var isPresented: Bool
    var placeholder: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

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

    final class Coordinator: NSObject, UISearchBarDelegate {
        var parent: NativeSearchBar
        init(_ parent: NativeSearchBar) { self.parent = parent }

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
}

struct SitemapNavigationView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var viewModel = SitemapPageViewModel()
    @State private var hasSeenActivePhase = false
    @State private var isSearchPresented = false
    var onShowSideMenu: (() -> Void)?

    var body: some View {
        NavigationStack {
            sitemapContent
        }
        .environment(\.sitemapSideMenuAction, onShowSideMenu)
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

        if viewModel.showSearchField {
            if #available(iOS 26.0, *) {
                // iOS 26: use safeAreaInset for reliable bottom-above-keyboard placement.
                // .searchable on iOS 26 places the bar at the top after the first use due to
                // UINavigationController caching UISearchController placement state.
                page
                    .safeAreaInset(edge: .bottom) {
                        if isSearchPresented {
                            NativeSearchBar(
                                text: $viewModel.searchText,
                                isPresented: $isSearchPresented,
                                placeholder: String(localized: "search_items", comment: "")
                            )
                            .frame(height: 56)
                        }
                    }
            } else {
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
            }
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

    init(viewModel: SitemapPageViewModel, onShowSideMenu: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onShowSideMenu = onShowSideMenu
    }

    init(onShowSideMenu: (() -> Void)? = nil) {
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
