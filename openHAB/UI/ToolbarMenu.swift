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
import Kingfisher
import OpenHABCore
import os.log
import SFSafeSymbols
import SwiftUI

// MARK: - Navigation targets

enum TargetController: Equatable {
    case webview
    case sitemap(String)
    case notifications
    case browser(String)
    case tile(String)
    case homeSelection
}

// MARK: - Connection status indicator

struct ConnectionView: View {
    static let cornerRadius: CGFloat = 14
    
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
    @State var scrollViewContentSize: Double = 0
    @State private var isTilesExpanded: Bool = true
    var onSelect: (TargetController) -> Void
    var onReload: (() -> Void)?

    @ScaledMetric private var iconWidth = 20.0

    var body: some View {
        GeometryReader { proxy in
            overlayContent(proxy: proxy)
        }
    }

    private func overlayContent(proxy: GeometryProxy) -> some View {
        ZStack(alignment: .topTrailing) {
            // Dimming backdrop — tapping dismisses the menu
            if isPresented {
                
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                    .onTapGesture { isPresented = false }
                    .transition(.opacity)
                
                let menu = menuContent(height: proxy.size.height * 0.8)
                    .transition(
                        .scale(scale: 0.01, anchor: .topTrailing)
                        .combined(with: .opacity)
                    )
                
                styleMenu(menu)
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                    .padding(.trailing, 8)
                    .padding(.top, 4)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isPresented)
    }
    
    @ViewBuilder
    private func styleMenu<Content: View>(_ menu: Content) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer {
                menu
            }.glassEffect(.regular, in: .rect(cornerRadius: ConnectionView.cornerRadius))
        } else {
            menu
                .background(.regularMaterial)
                .cornerRadius(ConnectionView.cornerRadius)
        }
    }

    // MARK: - Menu content

    private func menuContent(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            let scrollView = ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Main UI: Home + sidebar pages
                    sectionHeader(String(localized: "Main UI"))
                    menuRow(
                        icon: AnyView(Image("openHABIcon").resizable()),
                        label: String(localized: "Home"),
                        accessibilityId: "Home"
                    ) {
                        select(.webview)
                    }
                    if menuData.isLoading {
                        loadingRow(label: String(localized: "Pages"))
                    } else {
                        ForEach(menuData.uiPages, id: \.uid) { page in
                            menuRow(
                                icon: AnyView(pageIcon(for: page)),
                                label: page.label
                            ) {
                                select(.tile(page.url))
                            }
                        }
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
                    if menuData.isLoading {
                        loadingRow(label: String(localized: "Tiles"))
                    } else if !menuData.uiTiles.isEmpty {
                        // Collapsible Tiles header with disclosure chevron
                        Button {
                            isTilesExpanded.toggle()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemSymbol: isTilesExpanded ? .chevronDown : .chevronRight)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 10)
                                Text(String(localized: "Tiles"))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if isTilesExpanded {
                            ForEach(menuData.uiTiles, id: \.url) { tile in
                                menuRow(
                                    icon: AnyView(ImageView(url: tile.imageUrl).aspectRatio(contentMode: .fit)),
                                    label: tile.name
                                ) {
                                    select(.tile(tile.url))
                                }
                            }
                        }

                        Divider().padding(.horizontal, 12)
                    }

                    // System
                    sectionHeader(String(localized: "System"))
                    if Preferences.shared.getNotificationConnection() != nil,
                       !Preferences.shared.currentHomePreferences.demomode {
                        systemRow(symbol: .bell, label: String(localized: "notifications", comment: "")) { select(.notifications) }
                    }
                    systemRow(symbol: .house, label: String(localized: "Manage Homes")) { select(.homeSelection) }
                }
            }
                .frame(maxHeight: scrollViewContentSize > 0 ? min(scrollViewContentSize, height) : height)
            .scrollBounceBehavior(.basedOnSize)

            if #available(iOS 18.0, *) {
                scrollView.onScrollGeometryChange(for: Double.self, of: { $0.contentSize.height
                }) { oldValue, newValue in
                    scrollViewContentSize = newValue
                }
            } else {
                scrollView
            }
            
            Divider().padding(.horizontal, 12)

            // Connection status footer — always visible
            connectionFooter
        }
        .frame(width: 280)
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
