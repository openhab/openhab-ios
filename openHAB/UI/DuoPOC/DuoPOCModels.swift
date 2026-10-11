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

import SwiftUI

// MARK: - iPhone Duo proof of concept: the layout the host reports

//
// Everything else in the POC uses the real types of the app (`OHBridgeNavbarState`,
// `OHBridgeNavbarAction`, `OHBridgeMenuState`, `OHBridgeLayout`, ...). The one thing the real
// types cannot express is the layout the iPhone Duo needs, so it is modeled here.
//
// Read `DuoPOCMainUIView.swift` first: it holds the decision log for the whole POC.

/// The layout the host would send to Main UI (`info.layout` at startup, `layout.changed` later).
///
/// DECISION (assumed protocol extension, already commented on PR #1354):
/// - `leading` and `trailing` are added next to `top` and `bottom`. The iPhone Duo's right-hand
///   system strip is a trailing safe-area inset (third-party reports say about 84 pt), and
///   safe areas on Duo are asymmetric, so the bridge cannot assume equal left and right insets.
/// - `navbarHeight` may be 0. With a vertical system bar there is no top bar at all, and the
///   shim currently ignores a height that is not greater than 0 and falls back to 44.
///
/// The real `OHBridgeLayout` has neither field yet, so `bridgeLayout` can only send what exists
/// today. Until the protocol is extended, the page's own `env(safe-area-inset-*)` is the only
/// way the right inset can reach Main UI (Framework7 derives its `--f7-safe-area-*` variables
/// from it). Whether that is enough is exactly what the POC is meant to show on a Duo.
struct DuoPOCLayout: Equatable {
    var top: CGFloat
    var bottom: CGFloat
    var leading: CGFloat
    var trailing: CGFloat
    /// Height of a top bar that the host draws *outside* the reported `top` inset.
    var navbarHeight: CGFloat

    static let zero = DuoPOCLayout(top: 0, bottom: 0, leading: 0, trailing: 0, navbarHeight: 0)

    /// Builds the layout from the safe area of the page container.
    ///
    /// DECISION: the system navigation bar contributes to the safe area, so the bar's height is
    /// already inside `top` (or `leading`/`trailing` when the bar is vertical). Reporting a
    /// `navbarHeight` on top of that would make Main UI leave room twice, so the POC always
    /// reports 0 and lets the insets carry the bar. This is also why the real
    /// `OpenHABWebViewModel.currentLayout()`, which adds its constant 44, must not be used with a
    /// system bar. Leading/trailing use `EdgeInsets` rather than left/right so the values follow
    /// the layout direction.
    init(safeArea: EdgeInsets) {
        self.init(
            top: safeArea.top,
            bottom: safeArea.bottom,
            leading: safeArea.leading,
            trailing: safeArea.trailing,
            navbarHeight: 0
        )
    }

    init(top: CGFloat, bottom: CGFloat, leading: CGFloat, trailing: CGFloat, navbarHeight: CGFloat) {
        self.top = top
        self.bottom = bottom
        self.leading = leading
        self.trailing = trailing
        self.navbarHeight = navbarHeight
    }

    /// What the real bridge can carry today. `leading` and `trailing` are dropped until
    /// `OHBridgeLayout.Insets` has them (see the type's comment).
    var bridgeLayout: OHBridgeLayout {
        OHBridgeLayout(
            insets: .init(top: top, bottom: bottom),
            navbarHeight: navbarHeight
        )
    }
}

#if DEBUG

// MARK: - Preview fixtures

/// Navbar states for previews, built from the real bridge types and injected with the same hook
/// the UI tests use (`OpenHABWebViewModel.setUITestNavbar`). The page itself still loads from
/// the demo server; only its navbar is replaced.
enum DuoPOCFixtures {
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
#endif
