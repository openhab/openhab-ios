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
    case sitemap(String, widgetId: String? = nil)
    case notifications
    case browser(String)
    case tile(String)
}

// MARK: - Connection status indicator

struct ConnectionView: View {
    static let cornerRadius: CGFloat = 14

    @ObservedObject private var networkTracker = MainActorNetworkTracker.shared
    @State private var cachedHomePrefs: HomePreferences?

    var body: some View {
        HStack {
            if let activeConnection = networkTracker.activeConnection {
                let homePrefs = cachedHomePrefs
                let isLocal = activeConnection.configuration.url == homePrefs?.localConnectionConfig.url
                Image(systemSymbol: isLocal ? .wifi : .cloudFill)
                Text(homePrefs?.homeName ?? "").fontWeight(.medium)
            } else {
                Image(systemSymbol: .exclamationmarkIcloudFill)
                Text("Connecting…")
            }
        }
        .font(.footnote)
        .task {
            for await prefs in await Preferences.shared.currentHomePreferencesStream {
                cachedHomePrefs = prefs
            }
        }
    }
}

// MARK: - Toolbar dropdown menu

/// Toolbar dropdown menu replacing the SideMenu drawer.
struct ToolbarMenu: View {
    @Binding var isPresented: Bool
    var menuData: MenuDataService
    @State private var scrollViewContentSize: Double = 0
    // Section expansion is stored per home in `HomePreferences`. These `@State`
    // flags mirror the active home for immediate UI updates and are loaded from
    // (and written back to) that home whenever the menu opens or a section toggles.
    @State private var isTilesExpanded = true
    @State private var isMainUIExpanded = true
    @State private var isSitemapsExpanded = true
    @State private var isSystemExpanded = true
    @State private var isHomeExpanded = false
    // Two-phase header animation state — independent of isHomeExpanded so each gets its own
    // withAnimation context. Bool + ternary mirrors exactly how homeDetailsCollapsed drives
    // frame; using the same mechanism ensures both animate identically.
    @State private var headerDetailsHidden = false
    @State private var homeDetailsCollapsed = false
    @State private var showAppSettings = false
    @State private var showCurrentHomeSettings = false
    @State private var sitemapForWatch: String?
    @State private var sitemapForCarPlay: String?
    @State private var cachedHomePrefs: HomePreferences?
    var onSelect: (TargetController) -> Void
    var onReload: (() -> Void)?

    @ScaledMetric private var iconWidth = 20.0

    /// Shared curve so the section content and the container height animate in sync.
    private static let sectionAnimationDuration: Double = 0.25
    private static let sectionAnimation: Animation = .easeInOut(duration: sectionAnimationDuration)

    var body: some View {
        GeometryReader { proxy in
            overlayContent(proxy: proxy)
        }
        .onAppear { Task { await loadExpansionState() } }
        .onChange(of: isPresented) { _, newValue in
            if newValue {
                // Re-read in case the active home changed while the menu was closed.
                Task { await loadExpansionState() }
            } else {
                isHomeExpanded = false
                headerDetailsHidden = false
                homeDetailsCollapsed = false
            }
        }
        .sheet(isPresented: $showAppSettings) {
            NavigationStack {
                AppSettingsView()
            }
        }
        .sheet(isPresented: $showCurrentHomeSettings) {
            NavigationStack {
                HomeSettingsView()
            }
        }
    }

    /// Mirrors the active home's persisted section-expansion flags into local
    /// `@State`, defaulting to expanded when a home has no stored value yet.
    private func loadExpansionState() async {
        let prefs = await Preferences.shared.currentHomePreferences
        cachedHomePrefs = prefs
        isMainUIExpanded = prefs.isMainUIExpanded ?? true
        isSitemapsExpanded = prefs.isSitemapsExpanded ?? true
        isTilesExpanded = prefs.isTilesExpanded ?? true
        isSystemExpanded = prefs.isSystemExpanded ?? true
        sitemapForWatch = prefs.sitemapForWatch
        sitemapForCarPlay = prefs.sitemapForCarPlay
        headerDetailsHidden = false
        homeDetailsCollapsed = false
    }

    /// Toggles `sitemap` as the one sent to the paired Apple Watch, persisting the
    /// choice (and its display label) to the active home, or clearing it if the
    /// same sitemap is double-tapped again.
    private func toggleWatchSitemap(_ sitemap: OpenHABSitemap) {
        let isToggleOff = sitemap.name == sitemapForWatch
        let sitemapName = sitemap.name
        let sitemapLabel = sitemap.label
        if isToggleOff { sitemapForWatch = nil } else { sitemapForWatch = sitemapName }
        Task {
            await Preferences.shared.modifyActiveHome { @Sendable prefs in
                if isToggleOff {
                    prefs.sitemapForWatch = ""
                    prefs.sitemapForWatchLabel = ""
                } else {
                    prefs.sitemapForWatch = sitemapName
                    prefs.sitemapForWatchLabel = sitemapLabel
                }
            }
        }
    }

    /// Toggles `sitemap` as the one shown in CarPlay, persisting the choice to the
    /// active home, or clearing it if the same sitemap is long-pressed again.
    private func toggleCarPlaySitemap(_ sitemap: OpenHABSitemap) {
        let isToggleOff = sitemap.name == sitemapForCarPlay
        let sitemapName = sitemap.name
        if isToggleOff { sitemapForCarPlay = nil } else { sitemapForCarPlay = sitemapName }
        Task {
            await Preferences.shared.modifyActiveHome { @Sendable prefs in
                if isToggleOff {
                    prefs.sitemapForCarPlay = ""
                } else {
                    prefs.sitemapForCarPlay = sitemapName
                }
            }
        }
    }

    /// A binding that updates the local `@State` mirror for an immediate UI
    /// response and writes the new value through to the active home so the
    /// choice persists per home and across restarts.
    private func expansionBinding(
        _ state: Binding<Bool>,
        persistTo setter: @escaping @Sendable (inout HomePreferences, Bool) -> Void
    ) -> Binding<Bool> {
        Binding(
            get: { state.wrappedValue },
            set: { newValue in
                state.wrappedValue = newValue
                let capturedValue = newValue
                Task {
                    await Preferences.shared.modifyActiveHome { @Sendable prefs in
                        setter(&prefs, capturedValue)
                    }
                }
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
        if let prefs = cachedHomePrefs,
           Preferences.getNotificationConnection(of: prefs) != nil,
           !prefs.demomode {
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
        let prefs = cachedHomePrefs
        let order = SortSitemapsOrder(rawValue: prefs?.sortSitemapsBy ?? 0) ?? .label
        let mode = prefs?.sitemapNameLabelDisplayMode ?? .label
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
        // Hidden until the current home has had at least one successful fetch —
        // consistent with how sitemaps/pages behave during the loading state.
        if menuData.hasSuccessfullyLoaded {
            menuRow(
                icon: AnyView(Image("openHABIcon").resizable()),
                label: String(localized: "Home"),
                accessibilityId: "Home"
            ) {
                select(.webview)
            }
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
        VStack(alignment: .leading, spacing: 0) {
            InlineHomePickerView(isMenuPresented: $isPresented)
            Divider().padding(.horizontal, 12)
        }
    }

    private func menuContent(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            let scrollView = ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Home section: header + picker that is always in the layout.
                    // Keeping homesMenu() in the layout at all times (height 0 when collapsed)
                    // avoids the jump that occurs when conditional insertion allocates space
                    // instantly before the transition visual can begin.
                    VStack(alignment: .leading, spacing: 0) {
                        homeHeader()
                        Divider()
                        homesMenu()
                            .opacity(isHomeExpanded ? 1 : 0)
                            .frame(maxHeight: isHomeExpanded ? nil : 0, alignment: .top)
                            .clipped()
                    }
                    .animation(Self.sectionAnimation, value: isHomeExpanded)

                    // Main UI: Home + sidebar pages
                    collapsibleSection(
                        title: "Main UI",
                        isExpanded: expansionBinding($isMainUIExpanded) { prefs, v in prefs.isMainUIExpanded = v }
                    ) {
                        mainUIMenu()
                    }

                    // Sitemaps
                    collapsibleSection(
                        title: "Sitemaps",
                        isExpanded: expansionBinding($isSitemapsExpanded) { prefs, v in prefs.isSitemapsExpanded = v },
                        isLoading: menuData.isLoading,
                        isEmpty: menuData.sitemaps.isEmpty
                    ) {
                        sitemapsMenu()
                    }

                    // Tiles
                    collapsibleSection(
                        title: "Tiles",
                        isExpanded: expansionBinding($isTilesExpanded) { prefs, v in prefs.isTilesExpanded = v },
                        isLoading: menuData.isLoading,
                        isEmpty: menuData.uiTiles.isEmpty
                    ) {
                        tilesMenu()
                    }

                    // System & App
                    collapsibleSection(
                        title: "System & App",
                        isExpanded: expansionBinding($isSystemExpanded) { prefs, v in prefs.isSystemExpanded = v },
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

        }
        .frame(width: 300)
    }

    // MARK: - Home header

    private func toggleHomeExpanded() {
        let half = Self.sectionAnimationDuration / 2
        if !isHomeExpanded {
            // Phase 1: fade out details (Bool ternary + withAnimation mirrors homeDetailsCollapsed).
            withAnimation(.easeInOut(duration: half)) { headerDetailsHidden = true }
            // Phase 2: collapse layout + rotate chevron (delayed by half).
            withAnimation(.easeInOut(duration: half).delay(half)) { homeDetailsCollapsed = true }
            // Expand picker with full sectionAnimation (drives homesMenu height/opacity).
            withAnimation(Self.sectionAnimation) { isHomeExpanded = true }
        } else {
            // Phase 1: restore layout + rotate chevron back (immediate, half duration).
            withAnimation(.easeInOut(duration: half)) { homeDetailsCollapsed = false }
            // Phase 2: fade in details (delayed so content appears after layout has opened).
            withAnimation(.easeInOut(duration: half).delay(half)) { headerDetailsHidden = false }
            // Collapse picker.
            withAnimation(Self.sectionAnimation) { isHomeExpanded = false }
        }
    }

    private func homeHeader() -> some View {
        // Phase 1 (fade): conditional views keyed to headerDetailsHidden transition in/out.
        // A hidden placeholder keeps the layout space so the header height doesn't jump.
        // Phase 2 (layout): homeDetailsCollapsed collapses the frame after the fade completes.
        HStack(alignment: .center, spacing: 0) {
            Button(action: toggleHomeExpanded) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemSymbol: .chevronRight)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 10)
                        .rotationEffect(.degrees(homeDetailsCollapsed ? 90 : 0))

                    let homePrefs = cachedHomePrefs
                    ZStack(alignment: .center) {
                        HomeAvatarView(photo: nil, iconName: HomeAvatarView.defaultIconName,
                                       color: HomeAvatarView.defaultColor, size: 28).hidden()
                        if !headerDetailsHidden, let homePrefs {
                            HomeAvatarView(
                                photo: AvatarImageHelper.load(for: homePrefs.id),
                                iconName: homePrefs.avatarIconName ?? HomeAvatarView.defaultIconName,
                                color: Color(hex: homePrefs.avatarColor ?? "") ?? HomeAvatarView.defaultColor,
                                size: 28
                            )
                            .transition(.opacity)
                        }
                    }
                    .frame(width: homeDetailsCollapsed ? 0 : nil)
                    .clipped()

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Homes")
                            .font(.footnote)
                            .fontWeight(.semibold)

                        ZStack(alignment: .topLeading) {
                            // Always-present placeholder keeps space during the fade.
                            ConnectionView().hidden()
                            if !headerDetailsHidden {
                                ConnectionView()
                                    .transition(.opacity)
                            }
                        }
                        .padding(.top, 3)
                        .frame(maxHeight: homeDetailsCollapsed ? 0 : 30, alignment: .top)
                        .clipped()
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)

            Button(action: { menuData.refresh(); onReload?(); isPresented = false }) {
                Image(systemSymbol: .arrowClockwise).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.trailing, homeDetailsCollapsed ? 0 : 12)

            ZStack {
                // Placeholder keeps gear button space during the fade.
                Image(systemSymbol: .gear).hidden()
                if !headerDetailsHidden {
                    Button(action: { isPresented = false; showCurrentHomeSettings = true }) {
                        Image(systemSymbol: .gear).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .allowsHitTesting(!headerDetailsHidden && !homeDetailsCollapsed)
            .frame(width: homeDetailsCollapsed ? 0 : nil)
            .clipped()
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
