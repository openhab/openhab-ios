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

// What Main UI's sidebar offers, rebuilt natively so the menu needs nothing from the page. It
// follows Main UI's own rules (`App.vue`, `js/admin-menu.ts`): pinned pages from the page list,
// the administration entries gated on the endpoints the server offers, and the signed-in user.

/// What the server told us about itself in `GET /rest/`.
struct MainUIServer: Equatable, Sendable {
    let majorVersion: Int?
    /// The endpoints it offers, e.g. "items", "rules", "auth".
    let endpoints: Set<String>

    /// Without the `auth` endpoint nobody can sign in, so everybody is an administrator.
    var requiresSignIn: Bool {
        endpoints.contains("auth")
    }

    /// Chat came with openHAB 5.
    var hasChat: Bool {
        (majorVersion ?? 0) >= 5
    }

    init(majorVersion: Int?, endpoints: Set<String>) {
        self.majorVersion = majorVersion
        self.endpoints = endpoints
    }

    init(_ properties: OpenHABServerProperties) {
        self.init(majorVersion: properties.majorVersion, endpoints: properties.linkTypes)
    }
}

/// What the user can do in Main UI.
enum MainUIAccess: Equatable {
    /// The server has no sign-in.
    case open
    case signedOut
    case signedIn(OHBridgeUser)

    var isAdministrator: Bool {
        switch self {
        case .open: true
        case .signedOut: false
        case let .signedIn(user): user.roles.contains(OHBridgeUser.administratorRole)
        }
    }

    /// - Parameters:
    ///   - server: Nil until `GET /rest/` has been read, when nothing can be said yet.
    ///   - auth: What the page reported. Nil while no page has been loaded since the app started,
    ///     which counts as signed out: the user may be signed in already, and tapping the
    ///     Administration header finds out.
    init?(server: MainUIServer?, auth: OHBridgeAuthState?) {
        guard let server else { return nil }
        if auth?.noAuth == true || !server.requiresSignIn {
            self = .open
        } else if let user = auth?.user {
            self = .signedIn(user)
        } else {
            self = .signedOut
        }
    }

    /// Whether a page limited to `visibleTo` shows. Such a page only ever shows to fewer users than
    /// one without, so nobody who is signed out sees it.
    func canSee(visibleTo: [String]) -> Bool {
        guard !visibleTo.isEmpty else { return true }
        switch self {
        case .open: return true
        case .signedOut: return false
        case let .signedIn(user):
            return visibleTo.contains("user:\(user.name)") || user.roles.contains { visibleTo.contains("role:\($0)") }
        }
    }
}

/// One entry that opens a Main UI page.
struct MainUIMenuEntry: Identifiable, Equatable {
    let id: String
    let label: String
    let symbol: SFSymbol
    /// The Main UI route, with the trailing slash it declares.
    let path: String
}

enum MainUIMenu {
    static let chatRoute = "/chat/"
    static let aboutRoute = "/about/"
    /// Main UI signs the user in from here when nobody is, and shows the profile when somebody is.
    static let profileRoute = "/profile/"

    static let aboutEntry = MainUIMenuEntry(
        id: "about",
        label: String(localized: "Help & About"),
        symbol: .questionmarkCircle,
        path: aboutRoute
    )

    /// The pinned pages `access` shows, in the order Main UI lists them.
    static func pinnedPages(_ pages: [OpenHABUIPage], access: MainUIAccess?) -> [OpenHABUIPage] {
        guard let access else { return pages.filter(\.visibleTo.isEmpty) }
        return pages.filter { access.canSee(visibleTo: $0.visibleTo) }
    }

    static func chatEntry(server: MainUIServer?) -> MainUIMenuEntry? {
        guard server?.hasChat == true else { return nil }
        return MainUIMenuEntry(
            id: "chat",
            label: String(localized: "Chat"),
            symbol: .bubbleLeftAndBubbleRight,
            path: chatRoute
        )
    }

    /// What Administration lists for an administrator. Each entry is there when the endpoints it
    /// works on are.
    static func administrationEntries(server: MainUIServer) -> [MainUIMenuEntry] {
        let endpoints = server.endpoints
        var entries: [MainUIMenuEntry] = []
        if !endpoints.isDisjoint(with: ["things", "items", "ui", "rules"]) {
            entries.append(MainUIMenuEntry(
                id: "settings",
                label: String(localized: "Settings"),
                symbol: .gearshape,
                path: "/settings/"
            ))
        }
        if endpoints.contains("addons") {
            entries.append(MainUIMenuEntry(
                id: "addons",
                label: String(localized: "Add-on Store"),
                symbol: .squareAndArrowDown,
                path: "/addons/"
            ))
        }
        if endpoints.contains("ui") {
            entries.append(MainUIMenuEntry(
                id: "developer",
                label: String(localized: "Developer Tools"),
                symbol: .hammer,
                path: "/developer/"
            ))
        }
        return entries
    }
}
