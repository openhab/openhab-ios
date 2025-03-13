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

//
//  SitemapSettingsView.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 13.03.25.
//  Copyright © 2025 openHAB e.V. All rights reserved.
//
import Kingfisher
import OpenHABCore
import os
import SwiftUI

struct SitemapSettingsView: View {
    @Binding var settingsRealTimeSliders: Bool
    @Binding var settingsIconType: IconType
    @Binding var settingsSortSitemapsBy: SortSitemapsOrder
    @Binding var settingsSitemapForWatch: String
    @Binding var sitemaps: [OpenHABSitemap]

    @State private var showingCacheAlert = false
    private let logger = Logger(subsystem: "org.openhab.app", category: "SitemapSettingsView")

    var body: some View {
        Section(header: Text(LocalizedStringKey("sitemap_settings"))) {
            Toggle(isOn: $settingsRealTimeSliders) {
                Text("Real-time Sliders")
            }

            Button {
                clearWebsiteCache()
                showingCacheAlert = true
            } label: {
                NavigationLink("Clear Image Cache", destination: EmptyView())
            }
            .foregroundColor(Color(uiColor: .label))
            .alert("cache_cleared", isPresented: $showingCacheAlert) {
                Button("OK", role: .cancel) {}
            }

            Picker(selection: $settingsIconType) {
                ForEach(IconType.allCases, id: \.self) { icontype in
                    Text(verbatim: "\(icontype)").tag(icontype)
                }
            } label: {
                Text("Icon Type")
            }

            Picker(selection: $settingsSortSitemapsBy) {
                ForEach(SortSitemapsOrder.allCases, id: \.self) { sortsitemaporder in
                    Text(verbatim: "\(sortsitemaporder)").tag(sortsitemaporder)
                }
            } label: {
                Text("Sort sitemaps by")
            }

            Picker(selection: $settingsSitemapForWatch) {
                ForEach(sitemaps, id: \.name) { sitemap in
                    Text(sitemap.label)
                }
            } label: {
                Text("Sitemap For Apple Watch")
            }
        }
    }

    func clearWebsiteCache() {
        logger.debug("Clearing image cache")
        KingfisherManager.shared.cache.clearMemoryCache()
        KingfisherManager.shared.cache.clearDiskCache()
        KingfisherManager.shared.cache.cleanExpiredDiskCache()
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var realTimeSliders = true
        @State var iconType: IconType = .png
        @State var sortSitemapsBy: SortSitemapsOrder = .label
        @State var sitemapForWatch = "Home"
        @State var sitemaps: [OpenHABSitemap] = [
            OpenHABSitemap(
                name: "home",
                icon: "",
                label: "Home",
                link: "http://192.168.1.100/rest/sitemaps/home",
                page: nil // Replace with actual OpenHABPage if needed
            ),
            OpenHABSitemap(
                name: "office",
                icon: "",
                label: "Office",
                link: "http://192.168.1.100/rest/sitemaps/office",
                page: nil // Replace with actual OpenHABPage if needed
            )
        ]
        var body: some View {
            NavigationView {
                Form {
                    SitemapSettingsView(
                        settingsRealTimeSliders: $realTimeSliders,
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
