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

// Who is signed in to Main UI, as far as the app has been told.
//
// DECISIONS
// - A sign-in belongs to an origin. Main UI keeps its login in the page's `localStorage`, which
//   every origin has of its own, so signing in on a home's local address does not sign anybody in
//   on its remote address. The state is therefore kept per home and origin, and a switch of
//   connection shows what is known about the new origin, never what was known about the old one.
// - The page is the only source (`auth.state` over the bridge). The web view loads Main UI in the
//   background on every connection change, whatever the app shows, so no request of the app's own
//   is needed. Until the page has said, the state is *unknown*, which is not *signed out*: the menu
//   shows that it is finding out instead of a lock.
// - Finding out must end. A page that never says (it is slow, fails, or is a Main UI that has no
//   store the shim can read) must not leave the menu waiting for ever, so `giveUp()` turns unknown
//   into signed out, which offers the lock again. A later report still wins.

/// What the app knows about who is signed in to Main UI on one origin.
enum MainUIAuthStatus: Equatable {
    /// Nothing reported yet for this origin: the page is still loading.
    case unknown
    /// The page reported.
    case known(OHBridgeAuthState)
    /// Nothing was reported in time. Treated as signed out, so the user can sign in.
    case gaveUp
}

/// Where a sign-in is kept: in one home, on one origin.
struct MainUIAuthKey: Hashable {
    let home: UUID?
    /// `scheme://host:port` in lower case, with the port always spelled out.
    let origin: String

    init(home: UUID?, origin: String) {
        self.home = home
        self.origin = origin
    }

    /// The origin of `url`, or nil when it is not a web address.
    init?(home: UUID?, url: URL?) {
        guard let url, let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased() else { return nil }
        let port = url.port ?? (scheme == "https" ? 443 : 80)
        self.init(home: home, origin: "\(scheme)://\(host):\(port)")
    }
}

/// The sign-in state of every origin the app has seen a page from, and which one is in use.
struct MainUIAuthTracker: Equatable {
    private var states: [MainUIAuthKey: MainUIAuthStatus] = [:]
    /// The home and origin Main UI is being loaded from now.
    private(set) var active: MainUIAuthKey?

    /// What to show for the active origin.
    var status: MainUIAuthStatus {
        active.flatMap { states[$0] } ?? .unknown
    }

    /// Switches to another origin (connection change, home switch). Nil when there is no
    /// connection: nothing is known then.
    mutating func activate(_ key: MainUIAuthKey?) {
        active = key
    }

    /// A page reported who is signed in. It is kept for the origin the page came from, which may
    /// no longer be the active one: a page that was still loading when the connection changed
    /// reports late, and must not be taken for the new origin's.
    mutating func report(_ state: OHBridgeAuthState, from key: MainUIAuthKey) {
        states[key] = .known(state)
    }

    /// The page for the active origin did not report in time. Leaves what is known alone.
    mutating func giveUp() {
        guard let active, states[active] == nil || states[active] == .unknown else { return }
        states[active] = .gaveUp
    }

    /// Forgets that the active origin gave up, so that its next load is waited for again.
    mutating func startWaiting() {
        guard let active, states[active] == .gaveUp else { return }
        states[active] = nil
    }
}
