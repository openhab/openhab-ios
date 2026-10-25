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

// Signing in to Main UI leaves Main UI. It sends the web view to openHAB's own authorize page
// (`/auth?response_type=code&…`), which is not Main UI: the shim does not run there and the page
// has no bridge. That page has a Cancel button, `<a href="/">`, which goes to the root of the
// server. On a local connection that is Main UI's front page, on a cloud connection it is the
// cloud's own site: either way not where the user came from.
//
// DECISIONS
// - The app sees that link in the web view's navigation delegate, so nothing is needed from the
//   shim to know the user cancelled. It stops that navigation and puts the user back instead.
// - Back means the route Main UI was on when the sign-in began. Going back in the web view's
//   own history would land on the profile route, which starts the sign-in again.
// - The sign-in itself stays in the web view that holds Main UI. Main UI keeps the PKCE verifier
//   in that page's `sessionStorage` and finishes the sign-in when the authorize page sends the
//   user back to it with a code, so the authorize page cannot be shown in a web view of its own
//   without the app taking over the code exchange.

enum MainUILogin {
    /// What to do when the user cancels: depends on what they were looking at when the sign-in
    /// began, which was not necessarily Main UI. The sign-in is started from the menu, so it is
    /// as likely to begin on a sitemap or a tile.
    enum WayBack: Equatable {
        /// Show Main UI at `path` (nil for its front page).
        case mainUI(path: String?)
        /// Show the sitemap again, and load Main UI at `route` behind it, where it reports who is
        /// signed in.
        case sitemap(TargetController, mainUIRoute: String)
        /// Show the tile again.
        case tile(url: String)
    }

    /// Where Main UI sends the user to sign in. It does so from the profile route.
    static let authorizePath = "/auth"
    static let profileRoute = MainUIMenu.profileRoute

    /// Whether `url` is openHAB's authorize page, which may sit behind a cloud connection's path.
    static func isAuthorizePage(_ url: URL?) -> Bool {
        guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        let path = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        guard path.hasSuffix(authorizePath) else { return false }
        return components.queryItems?.contains { $0.name == "response_type" } == true
    }

    /// Whether following `link` on `page` is the Cancel button of the authorize page: a link to
    /// the root of the same server.
    static func isCancel(link: URL, on page: URL?) -> Bool {
        guard isAuthorizePage(page), let page else { return false }
        guard link.host?.lowercased() == page.host?.lowercased(), link.port == page.port else { return false }
        return link.path == "/" && link.query == nil
    }

    /// The route to put the user back on when they cancel: where Main UI was when the sign-in
    /// began. The sign-in starts from the profile route, so that is not where they were.
    static func routeBeforeLogin(path: String?, history: [String]) -> String {
        guard let path else { return "/" }
        guard path == profileRoute else { return path }
        let before = history.dropLast().last { $0 != profileRoute }
        return before ?? "/"
    }

    static func wayBack(from previous: TargetController?, route: String) -> WayBack {
        switch previous {
        case .sitemap?:
            .sitemap(previous ?? .webview, mainUIRoute: route)
        case let .tile(url)?:
            .tile(url: url)
        default:
            .mainUI(path: route == "/" ? nil : route)
        }
    }
}
