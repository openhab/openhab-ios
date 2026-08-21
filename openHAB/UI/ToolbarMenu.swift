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
    /// A MainUI SPA page identified by its client-side route (e.g. `/page/{uid}`).
    /// Rendered in the same web view as `.webview`; kept distinct so a reload
    /// returns to this page rather than the MainUI root.
    case mainUIPage(String)
    case sitemap(String)
    case notifications
    case browser(String)
    case tile(String)
}

// MARK: - Connection status indicator

struct ConnectionView: View {
    static let cornerRadius: CGFloat = 14

    @ObservedObject private var networkTracker = MainActorNetworkTracker.shared

    var body: some View {
        HStack {
            if let activeConnection = networkTracker.activeConnection {
                let homePrefs = Preferences.shared.currentHomePreferences
                let isLocal = activeConnection.configuration.url == homePrefs.localConnectionConfig.url
                Image(systemSymbol: isLocal ? .wifi : .cloudFill)
                Text(homePrefs.homeName).fontWeight(.medium)
            } else {
                Image(systemSymbol: .exclamationmarkIcloudFill)
                Text("Connecting…")
            }
        }
        .font(.footnote)
    }
}

// MARK: - Toolbar dropdown menu

/// Toolbar dropdown menu replacing the SideMenu drawer.
struct ToolbarMenu: View {
    @Binding var isPresented: Bool
    @ObservedObject var menuData: MenuDataService
    @State private var scrollViewContentSize: Double = 0
    // Section expansion is stored per home in `HomePreferences`. These `@State`
    // flags mirror the active home for immediate UI updates and are loaded from
    // (and written back to) that home whenever the menu opens or a section toggles.
    @State private var isTilesExpanded = true
    @State private var isMainUIExpanded = true
    @State private var isSitemapsExpanded = true
    @State private var isSystemExpanded = true
    @State private var isHomeExpanded = false
    @State private var showAppSettings = false
    @State private var sitemapForWatch: String?
    @State private var sitemapForCarPlay: String?
    var onSelect: (TargetController) -> Void
    var onReload: (() -> Void)?

    @ScaledMetric private var iconWidth = 20.0

    /// Shared curve so the section content and the container height animate in sync.
    private static let sectionAnimation: Animation = .easeInOut(duration: 0.25)

    var body: some View {
        GeometryReader { proxy in
            overlayContent(proxy: proxy)
        }
        .onAppear { loadExpansionState() }
        .onChange(of: isPresented) { _, newValue in
            if newValue {
                // Re-read in case the active home changed while the menu was closed.
                loadExpansionState()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { isHomeExpanded = false }
            }
        }
        .sheet(isPresented: $showAppSettings) {
            NavigationStack {
                AppSettingsView()
            }
        }
    }

    /// Mirrors the active home's persisted section-expansion flags into local
    /// `@State`, defaulting to expanded when a home has no stored value yet.
    private func loadExpansionState() {
        let prefs = Preferences.shared.currentHomePreferences
        isMainUIExpanded = prefs.isMainUIExpanded ?? true
        isSitemapsExpanded = prefs.isSitemapsExpanded ?? true
        isTilesExpanded = prefs.isTilesExpanded ?? true
        isSystemExpanded = prefs.isSystemExpanded ?? true
        sitemapForWatch = prefs.sitemapForWatch
        sitemapForCarPlay = prefs.sitemapForCarPlay
    }

    /// Toggles `sitemap` as the one sent to the paired Apple Watch, persisting the
    /// choice (and its display label) to the active home, or clearing it if the
    /// same sitemap is double-tapped again.
    private func toggleWatchSitemap(_ sitemap: OpenHABSitemap) {
        Preferences.shared.modifyActiveHome { prefs in
            if sitemap.name == sitemapForWatch {
                sitemapForWatch = nil
                prefs.sitemapForWatch = ""
                prefs.sitemapForWatchLabel = ""
            } else {
                sitemapForWatch = sitemap.name
                prefs.sitemapForWatch = sitemap.name
                prefs.sitemapForWatchLabel = sitemap.label
            }
        }
    }

    /// Toggles `sitemap` as the one shown in CarPlay, persisting the choice to the
    /// active home, or clearing it if the same sitemap is long-pressed again.
    private func toggleCarPlaySitemap(_ sitemap: OpenHABSitemap) {
        Preferences.shared.modifyActiveHome { prefs in
            if sitemap.name == sitemapForCarPlay {
                sitemapForCarPlay = nil
                prefs.sitemapForCarPlay = ""
            } else {
                sitemapForCarPlay = sitemap.name
                prefs.sitemapForCarPlay = sitemap.name
            }
        }
    }

    /// A binding that updates the local `@State` mirror for an immediate UI
    /// response and writes the new value through to the active home so the
    /// choice persists per home and across restarts.
    private func expansionBinding(
        _ state: Binding<Bool>,
        persistTo keyPath: WritableKeyPath<HomePreferences, Bool?>
    ) -> Binding<Bool> {
        Binding(
            get: { state.wrappedValue },
            set: { newValue in
                state.wrappedValue = newValue
                Preferences.shared.modifyActiveHome { $0[keyPath: keyPath] = newValue }
            }
        )
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
                .clipShape(.rect(cornerRadius: ConnectionView.cornerRadius))
        }
    }

    // MARK: - Menu content

    @ViewBuilder
    private func tilesMenu() -> some View {
        ForEach(menuData.uiTiles, id: \.url) { tile in
            menuRow(
                icon: AnyView(ImageView(url: tile.imageUrl).aspectRatio(contentMode: .fit)),
                label: tile.name
            ) {
                select(.tile(tile.url))
            }
        }
    }

    @ViewBuilder
    private func systemMenu() -> some View {
        if Preferences.shared.getNotificationConnection() != nil,
           !Preferences.shared.currentHomePreferences.demomode {
            systemRow(symbol: .bell, label: String(localized: "notifications", comment: "")) { select(.notifications) }
        }
        systemRow(symbol: .gear, label: String(localized: "App Settings")) {
            isPresented = false
            showAppSettings = true
        }
    }

    @ViewBuilder
    private func sitemapsMenu() -> some View {
        // `sitemapNameLabelDisplayMode` chooses which field(s) to show; when it is `.both`,
        // the sort order decides which one is the title. The list itself is
        // already ordered by `MenuDataService`.
        let prefs = Preferences.shared.currentHomePreferences
        let order = SortSitemapsOrder(rawValue: prefs.sortSitemapsBy) ?? .label
        let mode = prefs.sitemapNameLabelDisplayMode
        ForEach(menuData.sitemaps, id: \.name) { sitemap in
            let isWatch = sitemap.name == sitemapForWatch
            let isCarPlay = sitemap.name == sitemapForCarPlay
            menuDetailRow(
                icon: AnyView(sitemapIcon(for: sitemap)),
                title: mode.titleText(for: sitemap, sortedBy: order),
                detail: mode.detailText(for: sitemap, sortedBy: order),
                accessibilityId: sitemap.name,
                trailing: (isWatch || isCarPlay)
                    ? AnyView(
                        HStack(spacing: 4) {
                            if isWatch { Image(systemSymbol: .applewatchWatchface) }
                            if isCarPlay { Image(systemSymbol: .steeringwheel) }
                        }
                    )
                    : nil
            )
            // All three gestures are on this same view so SwiftUI can disambiguate the
            // single- vs double-tap count correctly (it can't across separate modifier
            // layers, e.g. one inside menuDetailRow and one attached by the caller).
            .onTapGesture(count: 2) { toggleWatchSitemap(sitemap) }
            .onTapGesture { select(.sitemap(sitemap.name)) }
            .onLongPressGesture { toggleCarPlaySitemap(sitemap) }
        }
    }

    @ViewBuilder
    private func mainUIMenu() -> some View {
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
                    select(.mainUIPage("/page/\(page.uid)"))
                }
            }
        }
    }

    fileprivate func homesMenu() -> some View {
        return VStack(alignment: .leading, spacing: 0) {
            InlineHomePickerView(isMenuPresented: $isPresented)
            Divider().padding(.horizontal, 12)
        }
        .transition(.blurReplace(.downUp))

    }

    private func menuContent(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            let scrollView = ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    homeHeader()
                    Divider()
                    if isHomeExpanded {
                        homesMenu()
                    }
                    // Main UI: Home + sidebar pages
                    collapsibleSection(
                        title: "Main UI",
                        isExpanded: expansionBinding($isMainUIExpanded, persistTo: \.isMainUIExpanded)
                    ) {
                        mainUIMenu()
                    }

                    // Sitemaps
                    collapsibleSection(
                        title: "Sitemaps",
                        isExpanded: expansionBinding($isSitemapsExpanded, persistTo: \.isSitemapsExpanded),
                        isLoading: menuData.isLoading,
                        isEmpty: menuData.sitemaps.isEmpty
                    ) {
                        sitemapsMenu()
                    }

                    // Tiles
                    collapsibleSection(
                        title: "Tiles",
                        isExpanded: expansionBinding($isTilesExpanded, persistTo: \.isTilesExpanded),
                        isLoading: menuData.isLoading,
                        isEmpty: menuData.uiTiles.isEmpty
                    ) {
                        tilesMenu()
                    }

                    // System & App
                    collapsibleSection(
                        title: "System & App",
                        isExpanded: expansionBinding($isSystemExpanded, persistTo: \.isSystemExpanded),
                        showDivider: false
                    ) {
                        systemMenu()
                    }
                }
            }
                .frame(maxHeight: scrollViewContentSize > 0 ? min(scrollViewContentSize, height) : height)
            .scrollBounceBehavior(.basedOnSize)
            // Host the animation on the sections' shared parent so a change in any
            // one flag also animates the *repositioning* of the sibling sections
            // below it — each section's own `.animation` only covers its own subtree.
            .animation(Self.sectionAnimation, value: isHomeExpanded)
            .animation(Self.sectionAnimation, value: isMainUIExpanded)
            .animation(Self.sectionAnimation, value: isSitemapsExpanded)
            .animation(Self.sectionAnimation, value: isTilesExpanded)
            .animation(Self.sectionAnimation, value: isSystemExpanded)

            if #available(iOS 18.0, *) {
                scrollView.onScrollGeometryChange(for: Double.self, of: { $0.contentSize.height
                }) { _, newValue in
                    // Animate the container growing/shrinking so it tracks the section
                    // content instead of snapping. Skip the first measurement (0 → N),
                    // which would otherwise shrink the menu from full height on open.
                    if scrollViewContentSize == 0 {
                        scrollViewContentSize = newValue
                    } else {
                        withAnimation(Self.sectionAnimation) { scrollViewContentSize = newValue }
                    }
                }
            } else {
                scrollView
            }

        }
        .frame(width: 280)
    }

    // MARK: - Home header

    @ViewBuilder
    private func homeHeader() -> some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: { withAnimation { isHomeExpanded.toggle() } }, label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Image(systemSymbol: isHomeExpanded ? .chevronDown : .chevronRight)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 10)
                        Text("Homes")
                            .font(.footnote)
                            .fontWeight(.semibold)
                    }
                    ConnectionView()
                        .padding(.leading, 18)
                }
                .contentShape(Rectangle())
            })
            .buttonStyle(.plain)
            Spacer(minLength: 8)
            Button(action: {
                menuData.refresh()
                onReload?()
                isPresented = false
            }, label: {
                Image(systemSymbol: .arrowClockwise)
                    .foregroundStyle(.secondary)
            })
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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

    // MARK: - Collapsible section

    /// A collapsible menu section: an optional loading/empty guard, a toggle
    /// header with a disclosure chevron, the expanded `content`, and an optional
    /// trailing divider.
    ///
    /// - Parameters:
    ///   - title: Localization key for the section label shown (uppercased) in the header.
    ///   - isExpanded: Binding to the section's persisted expansion flag.
    ///   - isLoading: When `true`, a `loadingRow` replaces the section.
    ///   - isEmpty: When `true` (and not loading), the section is hidden entirely.
    ///   - showDivider: Whether to append a trailing divider below the content.
    ///   - content: The section body, shown only while expanded.
    @ViewBuilder
    private func collapsibleSection(
        title: String.LocalizationValue,
        isExpanded: Binding<Bool>,
        isLoading: Bool = false,
        isEmpty: Bool = false,
        showDivider: Bool = true,
        @ViewBuilder content: () -> some View
    ) -> some View {
        let localizedTitle = String(localized: title)
        if isLoading {
            loadingRow(label: localizedTitle)
        } else if !isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                sectionToggleHeader(title: localizedTitle, isExpanded: isExpanded)

                if isExpanded.wrappedValue {
                    // Wrap in a single container so the transition has one stable
                    // identity to animate — a bare ViewBuilder group (TupleView /
                    // ForEach) is layout-transparent and won't transition.
                    VStack(alignment: .leading, spacing: 0) {
                        content()
                    }
                    .transition(.blurReplace(.downUp))
                }

                if showDivider {
                    Divider().padding(.horizontal, 12)
                }
            }
            // Value-based animation (not `withAnimation`): the section toggle
            // mutates the flag outside any `withAnimation` transaction. Diffing
            // the resolved value here animates the change regardless of trigger.
            .animation(Self.sectionAnimation, value: isExpanded.wrappedValue)
        }
    }

    /// Toggle header shared by every collapsible section: a disclosure chevron
    /// followed by the uppercased section title, driving `isExpanded`.
    private func sectionToggleHeader(title: String, isExpanded: Binding<Bool>) -> some View {
        Button {
            isExpanded.wrappedValue.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemSymbol: isExpanded.wrappedValue ? .chevronDown : .chevronRight)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 10)
                Text(title)
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

    /// A two-line variant of `menuRow`: an icon beside a primary `title` with an
    /// optional secondary `detail` below it, mirroring the home-picker rows. The
    /// `detail` line is omitted entirely when empty so equal name/label collapses
    /// to a single line.
    /// Not Button-based: sitemapsMenu() layers a double-tap (watch) and long-press (CarPlay)
    /// gesture on top of the single-tap select action, and a Button's own gesture recognizer
    /// wins the touch immediately — firing select() before a second tap can be recognized as
    /// a double-tap. A plain view lets SwiftUI's .onTapGesture/.onTapGesture(count: 2) pair
    /// disambiguate correctly, the way DrawerView's original implementation did.
    private func menuDetailRow(
        icon: AnyView,
        title: String,
        detail: String,
        accessibilityId: String? = nil,
        trailing: AnyView? = nil
    ) -> some View {
        HStack(spacing: 10) {
            icon
                .frame(width: iconWidth, height: iconWidth)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            if let trailing {
                Spacer()
                trailing
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityIdentifier(accessibilityId ?? title)
        .accessibilityAddTraits(.isButton)
    }

    private func systemRow(symbol: SFSymbol, label: String, action: @escaping () -> Void) -> some View {
        menuRow(
            icon: AnyView(Image(systemSymbol: symbol).resizable().aspectRatio(contentMode: .fit)),
            label: label,
            action: action
        )
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
