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

import OpenHABCore
import SFSafeSymbols
import SwiftUI

// MARK: - Main UI and tiles with a native navigation bar (every iOS version, vertical on iPhone Duo)

//
// Shows the Main UI web view, or a tile, with a real `NavigationStack` toolbar instead of the
// hand-built `menuBar` of `OpenHABRootView`, so the bar can move into the vertical strip of the
// iPhone Duo. `OpenHABRootView` uses this view on every iOS version. Only the vertical bar needs
// iOS 27.1; see decision 9.
//
// Everything else is reused from the app: the web view model and its bridge, the connection
// state, `ConnectingPlaceholder`, `OHBridgeIconView`, and the app menu (`AppMenu.swift`). This
// view started as a proof of concept (commit "feat(duo): proof of concept ..."), which ran
// standalone against the demo home.
//
// ============================================================================================
// DECISION LOG
// ============================================================================================
//
// 1. THE PROBLEM
//    - On iPhone Duo (Xcode 27.1 SDK), system bars (navigation bar, toolbar, tab bar) can lay out
//      vertically in a strip on the right. The strip is a trailing safe-area inset. Third-party
//      reports give about 84 pt; this is not measured here. Bars sit outside the safe area.
//    - Only system-owned bars move there. The custom `menuBar` is a hand-built SwiftUI view,
//      so (a) its background, which ignores only the `.top` safe area, ends abruptly at the
//      strip, and (b) its hamburger button stays in the top bar instead of moving into the strip.
//    - Foreground content must stay inside the safe area, backgrounds should extend past it,
//      and left/right insets must never be assumed equal.
//
// 2. WHY THE APP HAD A CUSTOM BAR FOR MAIN UI (inferred from the code; no commit message or
//    comment records the reason)
//    - Main UI is a Framework7 web app that owns its own navbar. The native bar was an overlay
//      that mirrored it: the page was scraped for title/buttons, the web navbar was hidden with
//      opacity but kept in the layout, and the overlay's height had to match `--f7-navbar-height`
//      so that it covered the web navbar exactly.
//    - The overlay also copied Framework7's hide-on-scroll slide (400 ms curve) and the large
//      title collapse by hand, and the hamburger scaled and faded into the dropdown menu.
//    - Sitemaps are native SwiftUI, so they already use a real NavigationStack bar.
//
// 3. WHAT PR #1354 CHANGES (https://github.com/openhab/openhab-ios/pull/1354)
//    - Main UI reports its navbar as data (`navbar.state`: title, titleInContent, hidden, back,
//      leading, trailing) instead of the app scraping HTML, and the app answers with
//      `navbar.activate` / `nav.back`.
//    - The app owns the bar height (a constant) and tells the page via `layout`, instead of
//      matching the page's navbar height. That makes a system bar, whose height differs, workable.
//    - The bar is still a custom overlay in that PR; this view is the follow-up on top of it.
//
// 4. PROTOCOL EXTENSIONS THAT ARE NOT NEEDED SO FAR
//    - `layout` could carry leading and trailing insets next to top and bottom.
//    - `layout.navbarHeight` may be 0 ("no top bar").
//    The real `OHBridgeLayout` and the shim do not have the first, and the shim falls back to
//    44 for a height of 0. `MainUILayout` models the extended layout and sends what the real type
//    can carry. Main UI's pages stay clear of the strip without the extension (tested on the
//    iPhone Duo with the demo home and a real home), so it is not needed until a page is found
//    that draws under the strip.
//
// 5. WHAT THIS VIEW DOES
//    - `NavigationStack` + `.toolbar` carries back, actions, connection state and the menu.
//      System bars are outside the safe area, so the "background ends at the strip" problem
//      cannot occur; the web view ignores the safe area (as before), so the page background
//      runs behind the bars and the strip.
//    - Main UI is told the real safe area, including leading/trailing, never derived from the
//      device idiom or orientation. The inner display ignores orientation masks and the idiom is
//      not a layout signal, so size classes and insets are the only inputs.
//    - A tile is a plain website without the bridge. It gets the same bar with its title and the
//      menu button only, and its web view stays below the bar (it does not ignore the safe area).
//
// 6. FEATURE MAPPING (everything the custom bar did, and what replaces it)
//    - Title            -> `navigationTitle`, inline. `titleInContent` -> empty title, as before.
//    - Back             -> custom `.cancellationAction` item calling `bridge.back()` (history
//                          lives in the web page, so NavigationStack's own back is not used).
//    - Actions          -> toolbar items. On a horizontal bar the item shows the page's icon
//                          (`OHBridgeIconView`), as before. A vertical bar needs a symbol AND a
//                          title, so there the item is a `Label` with an SF Symbol mapped from the
//                          icon name (generic fallback) and the label, or for an icon-only action
//                          its icon name (`OHBridgeNavbarAction.accessibilityName`). `disabled`
//                          maps one to one; tapping calls `bridge.activateNavbarAction(_:)`.
//                          (A custom view in a `Label` icon is not treated as a symbol; the POC
//                          showed the title as text instead.)
//    - Text-only action -> on a horizontal bar, a normal text button. On a vertical bar text-only
//                          items do not appear, so they move into `ToolbarOverflowMenu`, which is
//                          reachable on both axes. (Needs a run on Duo to confirm.)
//    - Several actions  -> the system toolbar overflow replaces the hand-built "..." popover.
//    - Hide on scroll   -> `toolbarVisibility(.hidden, for: .navigationBar)`, driven by
//                          `navbar.hidden`. The slide is the system's, not the 400 ms Framework7
//                          curve.
//    - Offline / connecting indicator -> an ordinary toolbar item with symbol and title, using
//                          the same conditions as the custom bar (no active connection: offline,
//                          page loading: connecting). It is placed directly after the back
//                          button, in the same placement, so it always stays to the right of (or
//                          below, on a vertical bar) the back button. Not important enough to
//                          get its own area; on a horizontal bar it is icon only.
//    - Menu button      -> the last trailing item on a horizontal bar, as before. On a vertical bar
//                          it is the topmost item (declared first, in the leading placement): the
//                          items above it come and go, and a menu button below them would jump
//                          whenever one appears or disappears.
//    - Hamburger animation -> not important; the system morphs the popover out of the button.
//
// 7. MENU
//    - The app menu is a popover from the toolbar button, shared with the sitemaps; see
//      `AppMenu.swift` for its decisions. With Liquid Glass the system morphs the popover out of
//      the glass button it is anchored to and back on dismissal, which is the "hamburger and menu
//      in the same glass group, native appearing/disappearing animation" behavior.
//    - Open (needs the Duo): whether the popover morphs from a toolbar item in a vertical strip.
//      Fallback: `.sheet` with `.presentationDetents`.
//
// 8. LAYOUT REPORTING RULE
//    - The system bar is inside the safe area, so the reported layout is the safe area with
//      `navbarHeight` 0 (see `MainUILayout.init(safeArea:)`).
//    - It is only updated while the bar is visible. When Main UI hides its navbar it reflows its
//      own content, so also shrinking the reported insets would shift the page a second time.
//      The last visible layout stays in effect while hidden.
//    - `OpenHABWebViewModel.setSystemBarLayout(_:)` stores the layout, so the model's own sends
//      on page load use it instead of the custom bar's (constant 44 plus the web view's insets).
//
// 9. AVAILABILITY
//    - The compiler confirmed that `toolbarVerticalEdge` and `axisBehavior` need iOS 27.1 and
//      `ToolbarOverflowMenu` needs iOS 27.0, while the app targets iOS 18+. Only the vertical
//      strip needs them, so they are isolated: `readsBarOrientation()` turns `toolbarVerticalEdge`
//      into the `barIsVertical` environment value, `verticalPreferred()` applies `axisBehavior`,
//      and the overflow menu for text-only actions is behind `#available(iOS 27.1, *)`. Before
//      iOS 27.1 a bar is never vertical, so everything else is the same horizontal bar.
//    - This replaced the hand-built bar that `OpenHABRootView` used before iOS 27.1, together with
//      the full-screen overlay menu and the hand-built "..." actions popover. The page therefore
//      always gets the real safe area with `navbarHeight` 0, and the safe-area watcher in the
//      shim (decision 11) matters on every version.
//    - Before iOS 26 the system bar is transparent while the page is scrolled to its top, so the
//      bar gets an opaque background there (`opaqueBarBeforeLiquidGlass`). Not run on iOS 18 to 25:
//      the available simulators are iOS 27.0 and 27.1.
//    - The menu is a popover on every version. A pull down at the top of a popover dismisses it,
//      which is also what pull-to-refresh is. The menu is `interactiveDismissDisabled`, so the
//      pull down reloads it, and it closes itself on a tap outside (see `AppMenuButton.swift`).
//      Told apart by speed instead was not tried: it would take the popover's own recognizers.
//
// 10. TESTING THE DUO LAYOUT
//    - An iPhone Duo simulator (iOS 27.1) is a run destination, and previews render on the
//      selected destination, so the strip, the vertical bars and the trailing inset appear by
//      themselves. Which bars go vertical depends on the display and orientation (reports:
//      portrait inner display keeps horizontal bars). Use the canvas "Display" and
//      "Orientation" variants. Static preview snapshots may not show web content.
//
// 11. HIDING THE BAR MOVES THE SAFE AREA
//    - Framework7 hides its navbar when an expandable card opens (a location on the home page),
//      and the system bar hides with it. That shrinks the web view's top safe area
//      (`env(safe-area-inset-top)` went from 82 px to 0 px on the Duo) while the card is
//      animating. Framework7 lays the card out from the safe area it saw when the card opened
//      (82 px, the bar had not hidden yet) and again only on a `resize`, which the web view does
//      not send for a safe-area change. The card ended up 82 px too high, with its close button
//      above the screen. The old custom bar was an overlay and never changed the web view's safe
//      area, so this could not happen there.
//    - Measured (card top / `env()` top) while holding part of the bar's inset: held 82 -> 0 / 82,
//      held 1 -> -81 / 1, held 0 -> -82 / 0. The card top is always held - 82, so zero is not
//      special. Holding the full 82 px kept the card in place but pushed its content down by 82
//      px, so it had to scroll. Holding the inset is therefore not done.
//    - The fix is in the shim (`watchSafeArea` in oh-bridge-shim.js): it watches the safe area
//      and sends the page a `resize` event when it changes, once no card is moving. Framework7
//      then lays the opened card out from the live value. The card sits at y 0, fills the
//      display and needs no scrolling (three openings in a row, no held inset). A resize sent
//      by a timer 350 ms after the change hit the opening animation and left the card half open,
//      which is why the shim waits for the card to stop moving instead.
//    - Main UI / Framework7 should lay the opened card out from the live safe area itself; the
//      shim can go once they do. Only cards were tried, not other page types.
//
// 12. NOT DONE / UNVERIFIED
//    - Not run on the iPhone Duo simulator or a device by the author of this file. The vertical
//      bar behavior is taken from Apple's tech talk "Prepare your app for iPhone Duo" and
//      third-party write-ups. The local Xcode documentation search did not list
//      `toolbarVerticalEdge` or `axisBehavior`, but the build confirmed they exist in the SDK;
//      their runtime behavior is unverified.
//    - Whether a toolbar `Label` with a mapped SF Symbol is accepted in the vertical strip.
//    - The existing UI tests (`MainUILayoutUITests`, `WebMenuUITests`, `ToolbarMenuUITests`)
//      were written for the custom bar and have not been run against the native one. The
//      accessibility identifiers `HamburgerButton` and `NavbarProxyButton-<name>` are kept;
//      `MainMenuBar` is not, since the system bar has no container of that name.
//
// ============================================================================================

// MARK: - Bar orientation

/// Puts `toolbarVerticalEdge` into `barIsVertical` for the views inside the navigation container.
/// That environment value only exists from iOS 27.1, so this is where the app reads it and
/// everything else asks `barIsVertical`.
@available(iOS 27.1, *)
private struct BarOrientationReader: ViewModifier {
    @Environment(\.toolbarVerticalEdge) private var verticalEdge

    func body(content: Content) -> some View {
        content.environment(\.barIsVertical, verticalEdge != nil)
    }
}

// MARK: - Content inside the NavigationStack

/// Split from `MainUINavigationView` because `toolbarVerticalEdge` is only set for views
/// *inside* the navigation container, not for the view that creates it.
private struct MainUINavigationContent: View {
    @ObservedObject var webViewModel: OpenHABWebViewModel
    let activeConnection: ConnectionInfo?
    let tileTitle: String?
    let onReload: () -> Void

    /// True while the system lays its bars out vertically (iPhone Duo outer display, or inner
    /// display in landscape / Split View), false for a normal horizontal bar.
    /// DECISION: this, not `userInterfaceIdiom` or orientation, decides how toolbar items are
    /// arranged, as Apple asks apps not to branch on the idiom.
    @Environment(\.barIsVertical) private var barIsVertical
    @State private var safeArea = EdgeInsets()
    @State private var reportedLayout = MainUILayout.zero
    @State private var lastVisibleTopInset: CGFloat = 0

    /// While the bar is hidden by scrolling the page keeps the top safe area it had with the bar
    /// shown. A card, popup or search covering the page lays itself out from the shrunk one.
    /// Otherwise hiding moves the page's content, Framework7 reads that as a scroll in the other
    /// direction and shows the bar again, which moves the content back: the bar flickers.
    private var heldTopInset: CGFloat {
        guard navbar.hidden, navbar.covered != true else { return 0 }
        return max(0, lastVisibleTopInset - safeArea.top)
    }

    private var isTile: Bool {
        tileTitle != nil
    }

    /// A tile has no bridge, so the page's navbar (possibly left over from Main UI) is ignored.
    private var navbar: OHBridgeNavbarState {
        isTile ? .empty : webViewModel.navbar
    }

    var body: some View {
        ZStack {
            // The GeometryReader sits OUTSIDE `.ignoresSafeArea()` on purpose: it reads the real
            // safe area, while the Main UI web view inside it draws full bleed, as before.
            GeometryReader { proxy in
                OpenHABWebViewContainer(viewModel: webViewModel, heldTopInset: isTile ? 0 : heldTopInset)
                    .background(.clear)
                    .ignoresSafeArea(edges: isTile ? [] : .all)
                    .onChange(of: proxy.safeAreaInsets, initial: true) { _, insets in
                        safeArea = insets
                        if !navbar.hidden {
                            lastVisibleTopInset = insets.top
                        }
                        reportLayout(for: insets)
                    }
            }
            // Placeholder while a home is first loading, as in the custom-bar layout.
            if !isTile, !webViewModel.hasLoadedContent {
                ConnectingPlaceholder()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: webViewModel.hasLoadedContent)
        .onChange(of: navbar.hidden) { _, _ in reportLayout(for: safeArea) }
        .navigationTitle(tileTitle ?? (navbar.titleInContent ? "" : navbar.title))
        .toolbarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbarVisibility(navbar.hidden ? .hidden : .visible, for: .navigationBar)
        .animation(.default, value: navbar.hidden)
        .opaqueBarBeforeLiquidGlass()
        .toolbar { toolbarContent }
    }

    // MARK: Toolbar

    private var iconActions: [OHBridgeNavbarAction] {
        navbar.actions.filter { $0.icon != nil }
    }

    private var textOnlyActions: [OHBridgeNavbarAction] {
        navbar.actions.filter { $0.icon == nil }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // The menu button is the topmost item of a vertical bar, see `AppMenuToolbarContent`.
        AppMenuToolbarContent(slot: .verticalLeading)

        if let back = navbar.back {
            ToolbarItem(placement: .cancellationAction) {
                let title = back.label.flatMap { $0.isEmpty ? nil : $0 } ?? String(localized: "Back")
                Button(
                    action: { webViewModel.bridge.back() },
                    label: { Label(title, systemSymbol: .chevronLeft) }
                )
                .accessibilityIdentifier("NavbarProxyButton-\(title)")
            }
            .verticalPreferred()
        }

        // DECISION: same placement as the back button and declared right after it, so the
        // connection state stays to the right of the back button (below it on a vertical bar).
        // A different placement such as `.topBarLeading` leaves the order up to the system.
        if !isTile, activeConnection == nil {
            ToolbarItem(placement: .cancellationAction) {
                Button(
                    action: { onReload() },
                    label: { Label("Offline", systemSymbol: .wifiExclamationmark) }
                )
                .accessibilityIdentifier("ConnectionStateButton")
            }
            .verticalPreferred()
        } else if webViewModel.isLoading {
            ToolbarItem(placement: .cancellationAction) {
                Label("Connecting", systemSymbol: .arrowTrianglehead2ClockwiseRotate90)
                    .accessibilityIdentifier("ConnectionStateButton")
            }
            .verticalPreferred()
        }

        // Actions with an icon. The system moves the lowest priority items into the overflow
        // menu when space runs out, which replaces the hand-built "..." popover.
        ForEach(iconActions) { action in
            ToolbarItem(placement: .topBarTrailing) {
                Button(
                    action: { webViewModel.bridge.activateNavbarAction(action.id) },
                    label: { actionLabel(action) }
                )
                .disabled(action.disabled == true)
                .accessibilityLabel(action.accessibilityName)
                .accessibilityIdentifier("NavbarProxyButton-\(action.accessibilityName)")
            }
            .verticalPreferred()
        }

        // Text-only actions: a text button works on a horizontal bar. A vertical bar drops
        // items without a symbol, so there they go into the overflow menu instead.
        if !barIsVertical {
            ForEach(textOnlyActions) { action in
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action.label) { webViewModel.bridge.activateNavbarAction(action.id) }
                        .disabled(action.disabled == true)
                        .accessibilityIdentifier("NavbarProxyButton-\(action.accessibilityName)")
                }
            }
        } else if !textOnlyActions.isEmpty, #available(iOS 27.1, *) {
            ToolbarOverflowMenu {
                ForEach(textOnlyActions) { action in
                    Button(action.label) { webViewModel.bridge.activateNavbarAction(action.id) }
                        .disabled(action.disabled == true)
                }
            }
        }

        // The last trailing item of a horizontal bar.
        AppMenuToolbarContent(slot: .horizontalTrailing)
    }

    /// The page's icon on a horizontal bar; on a vertical bar a symbol plus a title, which that
    /// bar requires of every item.
    @ViewBuilder
    private func actionLabel(_ action: OHBridgeNavbarAction) -> some View {
        if !barIsVertical {
            OHBridgeIconView(icon: action.icon, size: 24, fallback: .questionmarkCircle)
        } else {
            Label(action.accessibilityName, systemSymbol: action.icon?.toolbarSymbol ?? .squareGrid2x2)
        }
    }

    /// See the layout reporting rule (8) in the decision log. A tile has no bridge to tell.
    /// Takes the insets as an argument because the `safeArea` state is not updated yet when
    /// this runs from the `onChange` that stores it.
    private func reportLayout(for insets: EdgeInsets) {
        guard !isTile, !navbar.hidden else { return }
        let layout = MainUILayout(safeArea: insets)
        guard layout != reportedLayout else { return }
        reportedLayout = layout
        webViewModel.setSystemBarLayout(layout.bridgeLayout)
    }
}

#if DEBUG

// MARK: - Previews

// Run these on the "iPhone Duo" destination; see decision 10. They run the real web view model
// against the demo home, so they need a network connection.

/// Navbar states built from the real bridge types, injected with the hook the UI tests use
/// (`OpenHABWebViewModel.setUITestNavbar`). The page itself still loads from the demo server;
/// only its navbar is replaced.
private enum MainUIPreviewNavbar {
    static let kitchen = OHBridgeNavbarState(
        title: "Kitchen",
        titleInContent: false,
        hidden: false,
        back: .init(label: "Overview"),
        leading: [],
        trailing: [OHBridgeNavbarAction(id: "7", label: "Edit", icon: .init(name: "f7:pencil", md: nil, svg: nil), disabled: nil)]
    )

    /// Several actions: icon with label, icon only, disabled, and one text-only.
    static let manyActions = OHBridgeNavbarState(
        title: "Overview",
        titleInContent: false,
        hidden: false,
        back: nil,
        leading: [],
        trailing: [
            OHBridgeNavbarAction(id: "1", label: "Edit", icon: .init(name: "f7:pencil", md: nil, svg: nil), disabled: nil),
            OHBridgeNavbarAction(id: "2", label: "", icon: .init(name: "f7:square_list", md: nil, svg: nil), disabled: nil),
            OHBridgeNavbarAction(id: "3", label: "Delete", icon: .init(name: "f7:trash", md: nil, svg: nil), disabled: true),
            OHBridgeNavbarAction(id: "4", label: "Save", icon: nil, disabled: nil)
        ]
    )

    /// A page whose large title is still shown inside the content.
    static let largeTitle = OHBridgeNavbarState(
        title: "Settings",
        titleInContent: true,
        hidden: false,
        back: nil,
        leading: [],
        trailing: []
    )
}

private struct MainUIPreviewHost: View {
    @StateObject private var webViewModel = OpenHABWebViewModel()
    @StateObject private var networkService = NetworkConnectionService()
    @State private var menuData = MenuDataService()
    var navbar: OHBridgeNavbarState?
    var tileTitle: String?

    var body: some View {
        MainUINavigationView(
            webViewModel: webViewModel,
            activeConnection: MainActorNetworkTracker.shared.activeConnection,
            tileTitle: tileTitle
        ) { webViewModel.loadWebView(force: true) }
            .environment(
                \.appMenu,
                AppMenuConfiguration(
                    menuData: menuData,
                    authStatus: webViewModel.authStatus,
                    currentContent: tileTitle == nil ? .webview : .tile(""),
                    onSelect: { _ in },
                    onReload: { webViewModel.loadWebView(force: true) }
                )
            )
            .onAppear {
                if let navbar {
                    webViewModel.setUITestNavbar(navbar)
                }
            }
    }
}

#Preview("Live demo page") {
    MainUIPreviewHost()
}

#Preview("Back + one action") {
    MainUIPreviewHost(navbar: MainUIPreviewNavbar.kitchen)
}

#Preview("Many actions + text-only action") {
    MainUIPreviewHost(navbar: MainUIPreviewNavbar.manyActions)
}

#Preview("Large title in content") {
    MainUIPreviewHost(navbar: MainUIPreviewNavbar.largeTitle)
}

#Preview("Tile") {
    MainUIPreviewHost(tileTitle: "Tile")
}

#endif

struct MainUINavigationView: View {
    @ObservedObject var webViewModel: OpenHABWebViewModel
    let activeConnection: ConnectionInfo?
    /// The title of a tile. Nil for Main UI, whose title comes from the page's navbar.
    var tileTitle: String?
    var onReload: () -> Void

    var body: some View {
        NavigationStack {
            MainUINavigationContent(
                webViewModel: webViewModel,
                activeConnection: activeConnection,
                tileTitle: tileTitle,
                onReload: onReload
            )
            .readsBarOrientation()
        }
    }
}

// MARK: - Icon mapping

private extension OHBridgeIcon {
    /// The SF Symbol shown in a vertical bar for a Main UI icon. Only Framework7 names that are
    /// common in navbars are mapped; anything else falls back to a generic symbol, and the
    /// action's title tells the buttons apart.
    var toolbarSymbol: SFSymbol? {
        guard let name else { return nil }
        let glyph = name.hasPrefix("f7:") ? String(name.dropFirst(3)) : name
        return switch glyph {
        case "pencil": .pencil
        case "trash": .trash
        case "plus": .plus
        case "square_list", "list_bullet": .listBullet
        case "gear", "gear_alt", "gear_alt_fill": .gear
        case "arrow_clockwise": .arrowClockwise
        case "square_arrow_up": .squareAndArrowUp
        case "checkmark": .checkmark
        case "xmark": .xmark
        case "info_circle": .infoCircle
        case "ellipsis", "ellipsis_circle": .ellipsis
        case "search", "magnifyingglass": .magnifyingglass
        case "doc_on_doc": .documentOnDocument
        case "play", "play_fill": .play
        default: nil
        }
    }
}

private extension EnvironmentValues {
    /// Whether the system lays its bars out vertically, in a strip. Only iOS 27.1 can; earlier
    /// systems always have a horizontal bar.
    @Entry var barIsVertical = false
}

private extension View {
    @ViewBuilder
    func readsBarOrientation() -> some View {
        if #available(iOS 27.1, *) {
            modifier(BarOrientationReader())
        } else {
            self
        }
    }

    /// A bar that is opaque from the start. Before iOS 26 the system bar is transparent while the
    /// page is scrolled to its top, which would let the web page show through the title.
    @ViewBuilder
    func opaqueBarBeforeLiquidGlass() -> some View {
        if #available(iOS 26, *) {
            self
        } else {
            toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

private extension ToolbarContent {
    /// Lets the item move into a vertical bar. Before iOS 27.1 there is none.
    @ToolbarContentBuilder
    func verticalPreferred() -> some ToolbarContent {
        if #available(iOS 27.1, *) {
            axisBehavior(.verticalPreferred)
        } else {
            self
        }
    }
}
