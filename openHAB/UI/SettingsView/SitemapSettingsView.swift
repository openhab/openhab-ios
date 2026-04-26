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

import Kingfisher
import OpenHABCore
import os
import SwiftUI

struct SitemapSettingsView: View {
    @Binding var settingsRealTimeSliders: Bool
    @Binding var settingsShowSearchField: Bool
    @Binding var settingsIconType: IconType
    @Binding var settingsSortSitemapsBy: SortSitemapsOrder
    @Binding var settingsSitemapForWatch: String
    @Binding var sitemaps: [OpenHABSitemap]

    @State private var showingCacheAlert = false
    @State var cacheSizeResult: Result<UInt, KingfisherError>?

    var body: some View {
        Section(header: Text(LocalizedStringKey("sitemap_settings"))) {
            realtimeSliderToggle
            searchFieldToggle
            cacheButton
            iconTypePicker
            sortOrderPicker
            watchSitemapPicker
        }
    }

    @ViewBuilder
    private var realtimeSliderToggle: some View {
        Toggle(isOn: $settingsRealTimeSliders) {
            Text("Real-time Sliders")
        }
    }

    @ViewBuilder
    private var searchFieldToggle: some View {
        Toggle(isOn: $settingsShowSearchField) {
            Text("Show Search Field")
        }
    }

    @ViewBuilder
    private var cacheButton: some View {
        Button {
            KingfisherManager.shared.cache.calculateDiskStorageSize { result in
                Task { @MainActor in
                    cacheSizeResult = result
                    showingCacheAlert = true
                }
            }
        } label: {
            NavigationLink("Check & Clear Image Cache", destination: EmptyView())
        }
        .foregroundStyle(Color(uiColor: .label))
        .alert(
            "Image Cache",
            isPresented: $showingCacheAlert,
            presenting: cacheSizeResult,
            actions: cacheAlertActions,
            message: cacheAlertMessage
        )
    }

    @ViewBuilder
    private var iconTypePicker: some View {
        Picker(selection: $settingsIconType) {
            ForEach(IconType.allCases, id: \.self) { icontype in
                Text(verbatim: "\(icontype)").tag(icontype)
            }
        } label: {
            Text("Icon Type")
        }
    }

    @ViewBuilder
    private var sortOrderPicker: some View {
        Picker(selection: $settingsSortSitemapsBy) {
            ForEach(SortSitemapsOrder.allCases, id: \.self) { sortsitemaporder in
                Text(verbatim: "\(sortsitemaporder)").tag(sortsitemaporder)
            }
        } label: {
            Text("Sort sitemaps by")
        }
    }

    @ViewBuilder
    private var watchSitemapPicker: some View {
        Picker("Sitemap for Apple Watch", selection: $settingsSitemapForWatch) {
            if sitemaps.isEmpty {
                Text("No sitemaps available").tag("").foregroundStyle(.secondary)
            } else {
                ForEach(sitemaps, id: \.name) { sitemap in
                    Text(sitemap.label).tag(sitemap.name)
                }
            }
        }
        .disabled(sitemaps.isEmpty)
    }

    @ViewBuilder
    private func cacheAlertActions(_ result: Result<UInt, KingfisherError>) -> some View {
        switch result {
        case .success:
            Button("Clear") {
                clearWebsiteCache()
            }
            Button("Cancel", role: .cancel) {}
        case .failure:
            Button("OK") {}
        }
    }

    @ViewBuilder
    private func cacheAlertMessage(_ result: Result<UInt, KingfisherError>) -> some View {
        switch result {
        case let .success(size):
            Text("Size: \(size / 1_048_576) MB")
        case let .failure(error):
            Text(error.localizedDescription)
        }
    }

    func clearWebsiteCache() {
        #if !DEBUG
        Logger.settingsView.debug("Clearing image cache")
        #endif
        KingfisherManager.shared.cache.clearMemoryCache()
        KingfisherManager.shared.cache.clearDiskCache()
        KingfisherManager.shared.cache.cleanExpiredDiskCache()
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var realTimeSliders = true
        @State var showSearchField = true
        @State var iconType: IconType = .svg
        @State var sortSitemapsBy: SortSitemapsOrder = .label
        @State var sitemapForWatch = "Home"
        @State var sitemaps: [OpenHABSitemap] = [
            OpenHABSitemap(
                name: "home",
                icon: "",
                label: "Home",
                link: "http://192.168.1.100/rest/sitemaps/home",
                page: nil
            ),
            OpenHABSitemap(
                name: "office",
                icon: "",
                label: "Office",
                link: "http://192.168.1.100/rest/sitemaps/office",
                page: nil
            )
        ]
        var body: some View {
            NavigationStack {
                Form {
                    SitemapSettingsView(
                        settingsRealTimeSliders: $realTimeSliders,
                        settingsShowSearchField: $showSearchField,
                        settingsIconType: $iconType,
                        settingsSortSitemapsBy: $sortSitemapsBy,
                        settingsSitemapForWatch: $sitemapForWatch,
                        sitemaps: $sitemaps
                    )
                }
            }
        }
    }
    return PreviewWrapper()
}
