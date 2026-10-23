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

/// The layout the host reports to Main UI while a system navigation bar is on screen
/// (`info.layout` at startup, `layout.changed` later). See `MainUINavigationView.swift` for the
/// reasoning.
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
/// from it).
struct MainUILayout: Equatable {
    static let zero = MainUILayout(top: 0, bottom: 0, leading: 0, trailing: 0, navbarHeight: 0)

    var top: CGFloat
    var bottom: CGFloat
    var leading: CGFloat
    var trailing: CGFloat
    /// Height of a top bar that the host draws *outside* the reported `top` inset.
    var navbarHeight: CGFloat

    /// What the real bridge can carry today. `leading` and `trailing` are dropped until
    /// `OHBridgeLayout.Insets` has them.
    var bridgeLayout: OHBridgeLayout {
        OHBridgeLayout(
            insets: .init(top: top, bottom: bottom),
            navbarHeight: navbarHeight
        )
    }

    /// Builds the layout from the safe area of the page container.
    ///
    /// DECISION: the system navigation bar contributes to the safe area, so the bar's height is
    /// already inside `top` (or `leading`/`trailing` when the bar is vertical). Reporting a
    /// `navbarHeight` on top of that would make Main UI leave room twice, so it is always 0
    /// and the insets carry the bar. Leading/trailing use `EdgeInsets` rather than left/right so
    /// the values follow the layout direction.
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
}
