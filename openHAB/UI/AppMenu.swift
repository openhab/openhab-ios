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

import SFSafeSymbols
import SwiftUI
import UIKit

// MARK: - The app menu, the same everywhere there is a navigation bar

//
// The menu button and the menu it opens, for every screen with a real navigation bar: Main UI and
// tiles (`MainUINavigationView`) and the sitemaps (`SitemapPageView`).
//
// DECISIONS (from the review of PR #1360 and the conversation around it)
// - The menu is a popover anchored to the menu button. A popover from a bar button follows the
//   button: on the iPhone Duo it comes out of the vertical strip and overlaps it, and when the
//   strip is on the other side after rotating, so is the menu. That is how Safari's menus
//   behave, which the review took as the reference.
// - A tap anywhere outside the popover closes it, including a tap on the other items of the bar.
//   UIKit lets the navigation bar stay tappable while a popover from one of its items is open,
//   so a tap on the Duo's strip would trigger that item and leave the menu open.
//   `PopoverClosesOnOutsideTaps` turns that off.
// - On a vertical bar the menu button is the topmost item, and on a horizontal bar the last
//   trailing one. The items above it come and go (back, connection state, page actions), so a menu
//   button below them would jump. `AppMenuToolbarContent` is two items for that: declare the
//   `.verticalLeading` one first and the `.horizontalTrailing` one last in a toolbar.
// - What the menu shows comes from the environment (`appMenu`), set once by `OpenHABRootView`, so
//   a screen only has to add the toolbar content and does not need to know what is in the menu.

/// What the menu needs from the root view. Set in the environment by `OpenHABRootView`.
struct AppMenuConfiguration: Equatable {
    let menuData: MenuDataService
    /// Main UI's sidebar as sent over the bridge.
    let webMenu: OHBridgeMenuState?
    /// The surface the root view shows, for the menu's current-row highlight.
    let currentContent: TargetController
    let onSelect: (TargetController) -> Void
    let onActivateWebMenuItem: (String) -> Void
    let onReload: () -> Void

    /// The closures are not compared: only what the menu shows decides whether it has changed.
    /// Comparing them would make every environment update look like a change.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.menuData === rhs.menuData && lhs.webMenu == rhs.webMenu && lhs.currentContent == rhs.currentContent
    }
}

extension EnvironmentValues {
    @Entry var appMenu: AppMenuConfiguration?
}

/// The menu button, with the menu in a popover from it.
struct AppMenuButton: View {
    let configuration: AppMenuConfiguration
    @State private var isPresented = false

    var body: some View {
        Button(
            action: { isPresented.toggle() },
            label: { Label("Menu", systemSymbol: .line3Horizontal) }
        )
        .accessibilityIdentifier("HamburgerButton")
        #if DEBUG
        .onAppear {
            // UI tests open the menu from the start, so they need no tap on the bar.
            guard ProcessInfo.processInfo.environment["UITestOpenMenu"] != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isPresented = true
            }
        }
        #endif
        .popover(isPresented: $isPresented) {
            ToolbarMenu(
                isPresented: $isPresented,
                menuData: configuration.menuData,
                webMenu: configuration.webMenu,
                currentContent: configuration.currentContent,
                onSelect: configuration.onSelect,
                onActivateWebMenuItem: configuration.onActivateWebMenuItem,
                onReload: configuration.onReload
            )
            .background(PopoverClosesOnOutsideTaps())
            .presentationCompactAdaptation(.popover)
        }
    }
}

/// Which of the two positions of the menu button an `AppMenuToolbarContent` is.
enum AppMenuSlot {
    /// The topmost item of a vertical bar. Renders nothing on a horizontal bar. Declare it first.
    case verticalLeading
    /// The last trailing item of a horizontal bar. Renders nothing on a vertical bar. Declare it last.
    case horizontalTrailing
}

/// The menu button as toolbar content. Add both slots to a toolbar, see the decisions above.
/// Renders nothing when the environment has no menu, e.g. in a preview.
struct AppMenuToolbarContent: ToolbarContent {
    let slot: AppMenuSlot
    @Environment(\.appMenu) private var menu

    var body: some ToolbarContent {
        if let menu {
            if #available(iOS 27.1, *) {
                VerticalAwareAppMenuItem(slot: slot, configuration: menu)
            } else if slot == .horizontalTrailing {
                // Before iOS 27.1 a bar is never vertical.
                ToolbarItem(placement: .topBarTrailing) {
                    AppMenuButton(configuration: menu)
                }
            }
        }
    }
}

/// `toolbarVerticalEdge` is `nil` for a horizontal bar and `.leading` or `.trailing` for a vertical one.
@available(iOS 27.1, *)
private struct VerticalAwareAppMenuItem: ToolbarContent {
    let slot: AppMenuSlot
    let configuration: AppMenuConfiguration
    @Environment(\.toolbarVerticalEdge) private var verticalEdge

    var body: some ToolbarContent {
        if slot == .verticalLeading, verticalEdge != nil {
            ToolbarItem(placement: .cancellationAction) {
                AppMenuButton(configuration: configuration)
            }
            .axisBehavior(.verticalPreferred)
        }
        if slot == .horizontalTrailing, verticalEdge == nil {
            ToolbarItem(placement: .topBarTrailing) {
                AppMenuButton(configuration: configuration)
            }
        }
    }
}

/// Makes the popover it is in close on a tap outside of it, including a tap on the other items
/// of the bar it came from. By default UIKit lets the bar of the popover's source stay tappable
/// (`passthroughViews`), so a tap on the iPhone Duo's strip would trigger that button and leave
/// the menu open.
private struct PopoverClosesOnOutsideTaps: UIViewControllerRepresentable {
    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            var current: UIViewController? = self
            while let controller = current {
                if let popover = controller.popoverPresentationController
                    ?? controller.presentationController as? UIPopoverPresentationController {
                    popover.passthroughViews = nil
                    return
                }
                current = controller.parent
            }
        }
    }

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {}
}
