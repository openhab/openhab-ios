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
import SFSafeSymbols
import SwiftUI

// MARK: - iPhone Duo proof of concept: Main UI with a native navigation bar

//
// This is a proof of concept, not wired into `OpenHABRootView`. It shows the Main UI screen with
// a real `NavigationStack` toolbar instead of the hand-built `menuBar`, so that it works on the
// iPhone Duo. It runs the real stack: the real `OpenHABWebViewModel` and
// `OpenHABWebViewContainer` load the openHAB demo page through the bridge of PR #1354 (the
// default home is in demo mode), and every other piece comes from the app wherever possible:
//
//   - `NetworkConnectionService` + `NetworkTracker`  starts the connection, as the root view does
//   - `OpenHABWebViewModel` / `OpenHABWebViewContainer`  the web view and the bridge to Main UI
//   - `OHBridgeNavbarState` / `OHBridgeNavbarAction`  the navbar as the page sends it
//   - `OHBridgeIconView`                              icons drawn the way Main UI draws them
//   - `ToolbarMenu` + `MenuDataService`               the real menu, presented in a popover
//   - `ConnectingPlaceholder`                         the loading screen
//
// HOW TO RUN IT: select the "iPhone Duo" destination (the iOS 27.1 simulator) and use the
// previews in this file, or temporarily show `DuoPOCMainUIView` instead of `OpenHABRootView`.
// The system then draws the real right-hand strip and lays the toolbar out vertically on its
// own; nothing here simulates it. Previews need a network connection to the demo server.
//
// CHANGES TO PRODUCTION CODE (both are no-ops for the app today)
//   - `ToolbarMenu.isEmbedded` (default false): shows only the menu, without the dimming
//     backdrop and corner animation, so a popover can host it.
//   - `ConnectingPlaceholder` is no longer `private`, so this file can reuse it.
//
// ============================================================================================
// DECISION LOG
// ============================================================================================
//
// 1. THE PROBLEM
//    - On iPhone Duo (Xcode 27.1 SDK), system bars (navigation bar, toolbar, tab bar) can lay out
//      vertically in a strip on the right. The strip is a trailing safe-area inset. Third-party
//      reports give about 84 pt; this is not measured here. Bars sit outside the safe area.
//    - Only system-owned bars move there. `OpenHABRootView.menuBar` is a hand-built SwiftUI view,
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
//    - The bar is still a custom overlay in that PR, so a native bar is a follow-up on top of it.
//      This POC is that follow-up; it uses the PR's types as they are.
//
// 4. ASSUMED PROTOCOL EXTENSIONS (already commented on the PR; the POC assumes them)
//    - `layout` carries leading and trailing insets next to top and bottom.
//    - `layout.navbarHeight` may be 0 ("no top bar").
//    The real `OHBridgeLayout` and the shim do not have the first yet, and the shim falls back to
//    44 for a height of 0. `DuoPOCLayout` models the extended layout and sends what the real type
//    can carry. Not verified: whether Main UI's own CSS (`env(safe-area-inset-right)`, which
//    Framework7 turns into `--f7-safe-area-right`) already keeps content clear of the strip
//    without the protocol change. The live demo page answers this on the iPhone Duo.
//
// 5. WHAT THE POC DOES
//    - `NavigationStack` + `.toolbar` carries back, actions, connection state and the menu.
//      System bars are outside the safe area, so the "background ends at the strip" problem
//      cannot occur; the web view ignores the safe area (as the app's does), so the page
//      background runs behind the bars and the strip.
//    - The page is told the real safe area, including leading/trailing, never derived from the
//      device idiom or orientation. The inner display ignores orientation masks and the idiom is
//      not a layout signal, so size classes and insets are the only inputs.
//
// 6. FEATURE MAPPING (everything the custom bar did, and what replaces it)
//    - Title            -> `navigationTitle`, inline. `titleInContent` -> empty title, as before.
//    - Back             -> custom `.cancellationAction` item calling `bridge.back()` (history
//                          lives in the web page, so NavigationStack's own back is not used).
//    - Actions          -> toolbar items with an icon (`OHBridgeIconView`) AND a title, because a
//                          vertical bar needs both. An icon-only action gets its icon name as the
//                          title (`OHBridgeNavbarAction.accessibilityName`). `disabled` maps one
//                          to one; tapping calls `bridge.activateNavbarAction(_:)`.
//    - Text-only action -> on a horizontal bar, a normal text button. On a vertical bar text-only
//                          items do not appear, so they move into `ToolbarOverflowMenu`, which is
//                          reachable on both axes. (Needs a run on Duo to confirm.)
//    - Several actions  -> the system toolbar overflow replaces the hand-built "..." popover.
//    - Hide on scroll   -> `toolbarVisibility(.hidden, for: .navigationBar)`, driven by
//                          `navbar.hidden`. The slide is the system's, not the 400 ms Framework7
//                          curve.
//    - Offline / connecting indicator -> an ordinary toolbar item with symbol and title, using
//                          the same conditions as the root view (no active connection: offline,
//                          page loading: connecting). It is placed directly after the back
//                          button, in the same placement, so it always stays to the right of (or
//                          below, on a vertical bar) the back button. Not important enough to
//                          get its own area.
//    - Hamburger animation -> not important; replaced by the system popover morph (point 7).
//
// 7. MENU: POPOVER INSTEAD OF THE OVERLAY
//    - The real `ToolbarMenu` is an overlay that springs out of the top-trailing corner, and the
//      hamburger scales and fades into it. That only works because both are custom views. A
//      button in the system toolbar, which the vertical strip requires, cannot be scaled or
//      faded by the app.
//    - Replacement: present the real menu with `.popover` from the toolbar button, using
//      `ToolbarMenu(isEmbedded: true)`. With Liquid Glass the system morphs a popover out of the
//      glass button it is anchored to and back on dismissal. That is the "hamburger and menu in
//      the same glass group, native appearing/disappearing animation" behavior, done by the
//      system instead of by `GlassEffectContainer` + `glassEffectID`.
//    - Open (needs the Duo): whether the popover morphs from a toolbar item in a vertical strip
//      and which side it opens to. Fallback: `.sheet` with `.presentationDetents`.
//    - Not in the POC: selecting a sitemap, tile, notifications or settings entry. Those are
//      handled by `OpenHABRootView.handleMenuSelection`; the POC only handles Main UI pages.
//
// 8. LAYOUT REPORTING RULE
//    - The system bar is inside the safe area, so the POC reports the safe area as the layout
//      and `navbarHeight` 0 (see `DuoPOCLayout.init(safeArea:)`).
//    - The layout is only updated while the bar is visible. When Main UI hides its navbar it
//      reflows its own content, so also shrinking the reported insets would shift the page a
//      second time. The last visible layout stays in effect while hidden.
//    - The real `OpenHABWebViewModel` also sends its own layout (constant bar height 44 plus the
//      web view's safe area) whenever a page loads. The POC sends its layout again after each
//      navbar change to win that race. Integration must replace `currentLayout()` instead.
//
// 9. AVAILABILITY
//    - The compiler confirmed that `toolbarVerticalEdge` and `axisBehavior` need iOS 27.1 and
//      `ToolbarOverflowMenu` needs iOS 27.0, while the app targets iOS 18+. The POC views are
//      therefore `@available(iOS 27.1, *)`.
//    - When integrating, keep the current custom `menuBar` path for older systems (those cannot
//      have a vertical bar anyway) and switch to this native bar under `#available(iOS 27.1, *)`.
//      Both paths must consume the same `navbar.state`, so the logic is not duplicated.
//
// 10. NO SIMULATED STRIP
//    - An iPhone Duo simulator (iOS 27.1) is a run destination, and previews render on the
//      selected destination, so the strip, the vertical bars and the trailing inset appear by
//      themselves. An earlier version of this POC faked a trailing strip with padding; that was
//      removed because a fake strip cannot show how the real bars behave.
//    - Which bars go vertical depends on the display and orientation (reports: portrait inner
//      display keeps horizontal bars). Use the canvas "Display" and "Orientation" variants.
//    - Static preview snapshots may not show web content; use live mode or the simulator.
//
// 11. NOT DONE / UNVERIFIED
//    - Not run on the iPhone Duo simulator or a device by the author of this file. The vertical
//      bar behavior is taken from Apple's tech talk "Prepare your app for iPhone Duo" and
//      third-party write-ups. The local Xcode documentation search did not list
//      `toolbarVerticalEdge` or `axisBehavior`, but the build confirmed they exist in the SDK;
//      their runtime behavior is unverified.
//    - Whether a custom icon view (`OHBridgeIconView`) in a toolbar `Label` counts as a symbol
//      for the vertical bar. If not, icons need mapping to SF Symbols.
//    - `.tile` content (a plain website, no bridge) and route restore are not covered.
//    - UI tests (required by AGENTS.md for real UI changes) are a follow-up, not part of this POC.
//
// ============================================================================================

/// The Main UI screen with a native navigation bar, for the iPhone Duo POC.
@available(iOS 27.1, *)
struct DuoPOCMainUIView: View {
    @StateObject private var networkService = NetworkConnectionService()
    @StateObject private var webViewModel = OpenHABWebViewModel()
    @State private var menuData = MenuDataService()
    @State private var activeConnection: ConnectionInfo? = MainActorNetworkTracker.shared.activeConnection

    /// Runs once the view appears. Previews use it to replace the page's navbar.
    var prepare: (OpenHABWebViewModel) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            DuoPOCMainUIContent(
                webViewModel: webViewModel,
                menuData: menuData,
                activeConnection: activeConnection
            )
        }
        .onAppear {
            ImageDownloader.default.authenticationChallengeResponder = networkService
            prepare(webViewModel)
        }
        // The same subscription the root view uses to follow the active connection.
        .task {
            var previousConnection: ConnectionInfo?
            for await state in await NetworkTracker.shared.stateStream() {
                guard state.activeConnection != previousConnection else { continue }
                previousConnection = state.activeConnection
                activeConnection = state.activeConnection
            }
        }
    }
}

// MARK: - Content inside the NavigationStack

/// Split from `DuoPOCMainUIView` because `toolbarVerticalEdge` is only set for views *inside*
/// the navigation container, not for the view that creates it.
@available(iOS 27.1, *)
private struct DuoPOCMainUIContent: View {
    @ObservedObject var webViewModel: OpenHABWebViewModel
    let menuData: MenuDataService
    let activeConnection: ConnectionInfo?

    /// `.leading` or `.trailing` while the system lays its bars out vertically (iPhone Duo outer
    /// display, or inner display in landscape / Split View), `nil` for a normal horizontal bar.
    /// DECISION: this, not `userInterfaceIdiom` or orientation, decides how toolbar items are
    /// arranged, as Apple asks apps not to branch on the idiom.
    @Environment(\.toolbarVerticalEdge) private var verticalEdge
    @State private var isMenuPresented = false
    @State private var safeArea = EdgeInsets()
    @State private var reportedLayout = DuoPOCLayout.zero

    private var navbar: OHBridgeNavbarState {
        webViewModel.navbar
    }

    var body: some View {
        ZStack {
            // The GeometryReader sits OUTSIDE `.ignoresSafeArea()` on purpose: it reads the real
            // safe area, while the web view inside it draws full bleed, as the app's does.
            GeometryReader { proxy in
                OpenHABWebViewContainer(viewModel: webViewModel)
                    .background(.clear)
                    .ignoresSafeArea()
                    .onChange(of: proxy.safeAreaInsets, initial: true) { _, insets in
                        safeArea = insets
                        reportLayout()
                    }
            }
            // Same placeholder the root view shows while a home is first loading.
            if !webViewModel.hasLoadedContent {
                ConnectingPlaceholder()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: webViewModel.hasLoadedContent)
        // The model sends its own layout whenever a page loads; send ours again after it.
        .onChange(of: webViewModel.navbar) { _, _ in reportLayout(force: true) }
        .onChange(of: webViewModel.hasLoadedContent) { _, _ in reportLayout(force: true) }
        .navigationTitle(navbar.titleInContent ? "" : navbar.title)
        .toolbarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbarVisibility(navbar.hidden ? .hidden : .visible, for: .navigationBar)
        .animation(.default, value: navbar.hidden)
        .toolbar { toolbarContent }
    }

    /// See the layout reporting rule (8) in the decision log.
    private func reportLayout(force: Bool = false) {
        guard !navbar.hidden else { return }
        let layout = DuoPOCLayout(safeArea: safeArea)
        guard force || layout != reportedLayout else { return }
        reportedLayout = layout
        webViewModel.bridge.updateLayout(layout.bridgeLayout)
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
        if let back = navbar.back {
            ToolbarItem(placement: .cancellationAction) {
                let title = back.label.flatMap { $0.isEmpty ? nil : $0 } ?? String(localized: "Back")
                Button(
                    action: { webViewModel.bridge.back() },
                    label: { Label(title, systemSymbol: .chevronLeft) }
                )
                .accessibilityIdentifier("NavbarProxyButton-\(title)")
            }
            .axisBehavior(.verticalPreferred)
        }

        // Connection state is a normal item now, with the root view's conditions.
        // DECISION: same placement as the back button and declared right after it, so it stays
        // to the right of the back button (below it on a vertical bar). A different placement
        // such as `.topBarLeading` leaves the order up to the system.
        if activeConnection == nil {
            ToolbarItem(placement: .cancellationAction) {
                Button(
                    action: { webViewModel.loadWebView(force: true) },
                    label: { Label("Offline", systemSymbol: .wifiExclamationmark) }
                )
                .accessibilityIdentifier("ConnectionStateButton")
            }
            .axisBehavior(.verticalPreferred)
        } else if webViewModel.isLoading {
            ToolbarItem(placement: .cancellationAction) {
                Label("Connecting", systemSymbol: .arrowTriangle2Circlepath)
                    .accessibilityIdentifier("ConnectionStateButton")
            }
            .axisBehavior(.verticalPreferred)
        }

        // Actions with an icon: icon + title, so they are valid on a vertical bar. The system
        // moves the lowest priority items into the overflow menu when space runs out, which
        // replaces the hand-built "..." popover.
        ForEach(iconActions) { action in
            ToolbarItem(placement: .topBarTrailing) {
                Button(
                    action: { webViewModel.bridge.activateNavbarAction(action.id) },
                    label: {
                        Label(
                            title: { Text(action.label.isEmpty ? action.accessibilityName : action.label) },
                            icon: { OHBridgeIconView(icon: action.icon, size: 22, fallback: .questionmarkCircle) }
                        )
                    }
                )
                .disabled(action.disabled == true)
                .accessibilityIdentifier("NavbarProxyButton-\(action.label)")
            }
            .axisBehavior(.verticalPreferred)
        }

        // Text-only actions: a text button works on a horizontal bar. A vertical bar drops
        // items without a symbol, so there they go into the overflow menu instead.
        if verticalEdge == nil {
            ForEach(textOnlyActions) { action in
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action.label, action: { webViewModel.bridge.activateNavbarAction(action.id) })
                        .disabled(action.disabled == true)
                        .accessibilityIdentifier("NavbarProxyButton-\(action.label)")
                }
            }
        } else if !textOnlyActions.isEmpty {
            ToolbarOverflowMenu {
                ForEach(textOnlyActions) { action in
                    Button(action.label, action: { webViewModel.bridge.activateNavbarAction(action.id) })
                        .disabled(action.disabled == true)
                }
            }
        }

        // The menu button. It is the last item, so on a vertical strip it ends up with the other
        // trailing items, which is where the iPhone Duo user expects it.
        ToolbarItem(placement: .topBarTrailing) {
            menuButton
        }
        .axisBehavior(.verticalPreferred)
    }

    /// The popover is anchored to this button. See decision 7 for why it replaces the overlay.
    private var menuButton: some View {
        Button(
            action: { isMenuPresented.toggle() },
            label: { Label("Menu", systemSymbol: .line3Horizontal) }
        )
        .accessibilityIdentifier("HamburgerButton")
        .popover(isPresented: $isMenuPresented) {
            ToolbarMenu(
                isPresented: $isMenuPresented,
                menuData: menuData,
                webMenu: webViewModel.menu,
                currentContent: .webview,
                onSelect: { target in select(target) },
                onActivateWebMenuItem: { id in webViewModel.bridge.activateMenuItem(id) },
                onReload: { webViewModel.loadWebView(force: true) },
                isEmbedded: true
            )
            .presentationCompactAdaptation(.popover)
        }
    }

    /// Only Main UI pages. See decision 7.
    private func select(_ target: TargetController) {
        switch target {
        case .webview:
            webViewModel.bridge.navigate(to: "/")
        case let .mainUIPage(path):
            webViewModel.bridge.navigate(to: path)
        case .sitemap, .notifications, .browser, .tile:
            break
        }
    }
}

#if DEBUG

// MARK: - Previews

// Run these on the "iPhone Duo" destination; see "HOW TO RUN IT" above.

#Preview("Live demo page") {
    if #available(iOS 27.1, *) {
        DuoPOCMainUIView()
    }
}

#Preview("Back + one action") {
    if #available(iOS 27.1, *) {
        DuoPOCMainUIView(prepare: { $0.setUITestNavbar(DuoPOCFixtures.kitchen) })
    }
}

#Preview("Many actions + text-only action") {
    if #available(iOS 27.1, *) {
        DuoPOCMainUIView(prepare: { $0.setUITestNavbar(DuoPOCFixtures.manyActions) })
    }
}

#Preview("Large title in content") {
    if #available(iOS 27.1, *) {
        DuoPOCMainUIView(prepare: { $0.setUITestNavbar(DuoPOCFixtures.largeTitle) })
    }
}
#endif
