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

import OpenHABCore
import SFSafeSymbols
import SwiftUI

struct SitemapNavigationView: View {
    @StateObject public var viewModel = SitemapPageViewModel()
    let onShowSideMenu: () -> Void

    var body: some View {
        NavigationStack {
            SitemapPageView(viewModel: viewModel)
                .navigationTitle(viewModel.pageTitle)
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $viewModel.searchText, prompt: Text(NSLocalizedString("search_items", comment: "")))
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            onShowSideMenu()
                        } label: {
                            Image(systemSymbol: .line3Horizontal)
                                .font(.title)
                        }
                    }
                }
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
