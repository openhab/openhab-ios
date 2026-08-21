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
    @Binding var settingsIconType: IconType
    @Binding var settingsSortSitemapsBy: SortSitemapsOrder
    @Binding var settingsSitemapNameLabelDisplayMode: SitemapNameLabelDisplayMode
    @Binding var settingsSitemapForWatch: String
    @Binding var sitemaps: [OpenHABSitemap]

    @State private var showingCacheAlert = false
    @State var cacheSizeResult: Result<UInt, KingfisherError>?

    var body: some View {
        Section(header: Text(LocalizedStringKey("sitemap_settings"))) {
            realtimeSliderToggle
            cacheButton
            iconTypePicker
            displayModePicker
            sortOrderPicker
            watchSitemapPicker
        }
    }

    private var realtimeSliderToggle: some View {
        Toggle(isOn: $settingsRealTimeSliders) {
            Text("Real-time Sliders")
        }
    }

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
    private var displayModePicker: some View {
        Picker(selection: $settingsSitemapNameLabelDisplayMode) {
            ForEach(SitemapNameLabelDisplayMode.allCases) { mode in
                Text(verbatim: "\(mode)").tag(mode)
            }
        } label: {
            Text("Show sitemaps by")
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

    private var watchSitemapPicker: some View {
        Picker("Sitemap for Apple Watch", selection: $settingsSitemapForWatch) {
            if sitemaps.isEmpty {
                // Tag the placeholder with the stored selection so the Picker has a
                // matching tag (avoids the "invalid selection" warning while the
                // sitemap list is still loading).
                Text("No sitemaps available").tag(settingsSitemapForWatch).foregroundStyle(.secondary)
            } else {
                ForEach(sitemaps, id: \.name) { sitemap in
                    Text(settingsSitemapNameLabelDisplayMode.combinedText(for: sitemap, sortedBy: settingsSortSitemapsBy)).tag(sitemap.name)
                }
                if !sitemaps.contains(where: { $0.name == settingsSitemapForWatch }) {
                    // The stored selection isn't among the available sitemaps (e.g. a
                    // renamed/removed sitemap, or the default before one is chosen);
                    // surface it so the Picker always has a tag for its selection.
                    Text(settingsSitemapForWatch).tag(settingsSitemapForWatch).foregroundStyle(.secondary)
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
        @State var iconType: IconType = .svg
        @State var sortSitemapsBy: SortSitemapsOrder = .label
        @State var sitemapNameLabelDisplayMode: SitemapNameLabelDisplayMode = .label
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
                        settingsIconType: $iconType,
                        settingsSortSitemapsBy: $sortSitemapsBy,
                        settingsSitemapNameLabelDisplayMode: $sitemapNameLabelDisplayMode,
                        settingsSitemapForWatch: $sitemapForWatch,
                        sitemaps: $sitemaps
                    )
                }
            }
        }
    }
    return PreviewWrapper()
}
