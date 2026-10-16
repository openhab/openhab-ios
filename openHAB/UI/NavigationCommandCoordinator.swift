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

import Foundation

/// The concrete effect `OpenHABRootView` should perform in response to a `NavigationCommand`.
enum NavigationCommandAction: Equatable {
    /// Load Main UI directly at this path (`nil` = root). Performed regardless of what's
    /// currently shown.
    case showMainUI(path: String?)
    /// Main UI is already the visible surface, or must first be shown at its root —
    /// `ensureShown` says which — then this raw command is run in the live SPA router.
    case navigateLive(command: String, ensureShown: Bool)
    /// Main UI root was requested but is already the visible surface: nothing to do.
    case none
    /// Switch to (and resolve breadcrumbs for) this sitemap.
    case switchToSitemap(name: String, widgetId: String?)
}

/// Resolves a `NavigationCommand` — the output of `NotificationActionService` parsing a
/// notification's onClickAction, or a client-side navigation request — into the concrete
/// action `OpenHABRootView` should perform.
///
/// This is the seam between the notification pipeline (`NotificationCommandParser` →
/// `NotificationActionService` → `NavigationCommand`) and `OpenHABRootView`'s own state
/// (`showMainUI`, `webViewModel`, `currentContent`): decided as a pure function of
/// `isMainUIShown` so the join between parsing and routing can be tested directly, without
/// standing up the view itself.
enum NavigationCommandCoordinator {
    static func action(for command: NavigationCommand, isMainUIShown: Bool) -> NavigationCommandAction {
        switch command {
        case let .switchToWebView(path):
            switch WebViewNavigationRouter.route(for: path) {
            case let .path(resolvedPath):
                .showMainUI(path: resolvedPath)
            case .root:
                isMainUIShown ? .none : .showMainUI(path: nil)
            case let .liveCommand(rawCommand):
                .navigateLive(command: rawCommand, ensureShown: !isMainUIShown)
            }
        case let .switchToSitemap(name, widgetId):
            .switchToSitemap(name: name, widgetId: widgetId)
        }
    }
}
