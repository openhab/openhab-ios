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
import os.log
import SFSafeSymbols
import SwiftUI

// MARK: - Navigation targets

enum TargetController: Equatable {
    case webview
    case settings
    case sitemap(String)
    case notifications
    case browser(String)
    case tile(String)
    case homeSelection
}

// MARK: - Connection status indicator

struct ConnectionView: View {
    @StateObject private var networkTracker = MainActorNetworkTracker.shared

    var body: some View {
        HStack {
            if let activeConnection = networkTracker.activeConnection {
                Image(systemSymbol: .cloudFill)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                Text(activeConnection.configuration.url).font(.footnote)
            } else {
                Image(systemSymbol: .exclamationmarkIcloudFill)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                Text("connecting").font(.footnote)
            }
        }
    }
}

// MARK: - Toolbar dropdown menu

/// Toolbar dropdown menu replacing the SideMenu drawer.
struct ToolbarMenu: View {
    @Binding var isPresented: Bool
    @ObservedObject var menuData: MenuDataService
    var isWebViewActive: Bool
    var onSelect: (TargetController) -> Void
    var onReload: (() -> Void)?

    @ScaledMetric private var iconWidth = 20.0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Dimming backdrop — tapping dismisses the menu
            if isPresented {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { isPresented = false }
                    .transition(.opacity)

                menuContent
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isPresented)
    }

    // MARK: - Menu content

    private var menuContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Home
            menuRow(
                icon: AnyView(Image("openHABIcon").resizable()),
                label: String(localized: "Home"),
                accessibilityId: "Home",
                trailing: isWebViewActive ? AnyView(Image(systemSymbol: .arrowClockwise).foregroundStyle(.secondary)) : nil
            ) {
                select(.webview)
            }

            Divider().padding(.horizontal, 12)

            // Sitemaps
            if menuData.isLoading {
                loadingRow(label: String(localized: "Sitemaps"))
            } else if !menuData.sitemaps.isEmpty {
                sectionHeader(String(localized: "Sitemaps"))
                ForEach(menuData.sitemaps, id: \.name) { sitemap in
                    menuRow(
                        icon: AnyView(sitemapIcon(for: sitemap)),
                        label: sitemap.label
                    ) {
                        select(.sitemap(sitemap.name))
                    }
                }
                Divider().padding(.horizontal, 12)
            }

            // Tiles
            if !menuData.isLoading, !menuData.uiTiles.isEmpty {
                sectionHeader(String(localized: "Tiles"))
                ForEach(menuData.uiTiles, id: \.url) { tile in
                    menuRow(
                        icon: AnyView(ImageView(url: tile.imageUrl).aspectRatio(contentMode: .fit)),
                        label: tile.name
                    ) {
                        select(.tile(tile.url))
                    }
                }
                Divider().padding(.horizontal, 12)
            }

            // Pages
            if !menuData.isLoading, !menuData.uiPages.isEmpty {
                sectionHeader(String(localized: "Pages"))
                ForEach(menuData.uiPages, id: \.uid) { page in
                    menuRow(
                        icon: AnyView(pageIcon(for: page)),
                        label: page.label
                    ) {
                        select(.tile(page.url))
                    }
                }
                Divider().padding(.horizontal, 12)
            }

            // System
            sectionHeader(String(localized: "System"))
            systemRow(symbol: .gear, label: String(localized: "settings", comment: "")) { select(.settings) }
            if Preferences.shared.getNotificationConnection() != nil,
               !Preferences.shared.currentHomePreferences.demomode {
                systemRow(symbol: .bell, label: String(localized: "notifications", comment: "")) { select(.notifications) }
            }
            systemRow(symbol: .house, label: String(localized: "Manage Homes")) { select(.homeSelection) }

            Divider().padding(.horizontal, 12)

            // Connection status footer
            connectionFooter
        }
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
        .padding(.trailing, 8)
        .padding(.top, 4)
    }

    // MARK: - Connection footer

    private var connectionFooter: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                let homeName = Preferences.shared.currentHomePreferences.homeName
                if !homeName.isEmpty {
                    Text(homeName)
                        .font(.footnote)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                ConnectionView()
            }
            Spacer()
            Button {
                menuData.refresh()
                onReload?()
                isPresented = false
            } label: {
                Image(systemSymbol: .arrowClockwise)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Loading row

    private func loadingRow(label: String) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Row helpers

    private func menuRow(
        icon: AnyView,
        label: String,
        accessibilityId: String? = nil,
        trailing: AnyView? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon
                    .frame(width: iconWidth, height: iconWidth)
                Text(label)
                    .lineLimit(1)
                if let trailing {
                    Spacer()
                    trailing
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityId ?? label)
    }

    private func systemRow(symbol: SFSymbol, label: String, action: @escaping () -> Void) -> some View {
        menuRow(
            icon: AnyView(Image(systemSymbol: symbol).resizable().aspectRatio(contentMode: .fit)),
            label: label,
            action: action
        )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 2)
    }

    private func pageIcon(for page: OpenHABUIPage) -> some View {
        Group {
            if page.icon.isEmpty || page.icon.isNoneIcon {
                Image(systemSymbol: .squareGrid2x2).resizable().aspectRatio(contentMode: .fit)
            } else {
                let url = Endpoint.iconForDrawer(
                    rootUrl: MainActorNetworkTracker.shared.activeConnection?.configuration.url ?? "",
                    icon: page.icon
                ).url
                KFImage(url)
                    .placeholder { Image(systemSymbol: .squareGrid2x2).resizable().aspectRatio(contentMode: .fit) }
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }

    private func sitemapIcon(for sitemap: OpenHABSitemap) -> some View {
        Group {
            if sitemap.icon.isEmpty {
                Image("openHABIcon").resizable()
            } else {
                let url = Endpoint.iconForDrawer(
                    rootUrl: MainActorNetworkTracker.shared.activeConnection?.configuration.url ?? "",
                    icon: sitemap.icon
                ).url
                KFImage(url)
                    .placeholder { Image("openHABIcon").resizable() }
                    .resizable()
            }
        }
        .aspectRatio(contentMode: .fit)
    }

    // MARK: - Helpers

    private func select(_ target: TargetController) {
        isPresented = false
        onSelect(target)
    }
}

// MARK: - Toolbar button that toggles the menu

struct ToolbarMenuButton: View {
    @Binding var isMenuPresented: Bool

    var body: some View {
        Button {
            isMenuPresented.toggle()
        } label: {
            Image(systemSymbol: .line3Horizontal)
                .imageScale(.large)
        }
        .accessibilityIdentifier("HamburgerButton")
        .accessibilityLabel("Menu")
    }
}
