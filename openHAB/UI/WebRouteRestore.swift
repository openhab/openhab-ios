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
import OpenHABCore

/// Decides which Main UI pages to put back after a connection switch. The script that records
/// them is `webViewRouteRestoreJS`, and only reports pages the Main UI can open again on its own.
/// The deciding is done here in Swift, where it can be tested.
enum WebRouteRestore {
    /// What a load already knows about itself, for deciding whether to put the user back.
    struct Load {
        /// A page someone asked for by name, rather than us opening the Main UI on our own.
        let path: String?
        /// The user pulled to refresh, or the app is reloading after a problem.
        let force: Bool
        let isShowingTile: Bool
        /// Whether the user has moved around in this home since the app started.
        let hasCapturedThisSession: Bool
        /// The home's own start page, empty when none is set.
        let defaultMainUIPath: String
    }

    private struct Payload: Decodable {
        let history: [String]
        let url: String
    }

    /// The kind of message `webViewRouteRestoreJS` sends us.
    static let messageType = "routeState"

    /// We add one browser history entry per page, and iOS quietly stops accepting them after
    /// about a hundred in half a minute, which would leave the user on the wrong page. The
    /// Main UI's own list only ever grows, so cut it short. Nobody goes back twenty pages.
    static let maxSeededEntries = 20

    /// Settings pages ask for a login when the connection has no admin rights. Matched by
    /// address, since there is no dependable way to ask the Main UI which pages are protected.
    private static let adminPrefixes = ["/settings", "/developer", "/addons", "/setup-wizard"]

    /// Reads the message `webViewRouteRestoreJS` sends.
    static func snapshot(fromJSON json: String, connectionURL: String, capturedAt: Date = Date()) -> WebRouteSnapshot? {
        guard let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              !payload.history.isEmpty, !payload.url.isEmpty else { return nil }
        return WebRouteSnapshot(
            history: payload.history,
            url: payload.url,
            connectionURL: connectionURL,
            capturedAt: capturedAt
        )
    }

    /// Whether to put the user back where they were.
    ///
    /// Only when we are opening the Main UI by ourselves. If a particular page was asked for,
    /// the user pulled to refresh, or a tile is showing, that choice wins instead.
    ///
    /// The first time after the app starts, the home's own start page wins. Opening there is
    /// why it was set. Once the user has moved around, where they were is the better answer.
    static func snapshotToRestore(_ stored: WebRouteSnapshot?, for load: Load) -> WebRouteSnapshot? {
        guard let stored, load.path == nil, !load.force, !load.isShowingTile else { return nil }
        guard load.hasCapturedThisSession || load.defaultMainUIPath.isEmpty else { return nil }
        return stored
    }

    /// The pages to put back and the one to show, or nil if nothing usable is left.
    ///
    /// - Parameter dropAdmin: true when the user is landing on a different connection, which
    ///   may not have admin rights.
    static func seed(for snapshot: WebRouteSnapshot, dropAdmin: Bool) -> (history: [String], url: String)? {
        let pages = dropAdmin ? snapshot.history.filter { !isAdminPath($0) } : snapshot.history
        guard let last = pages.last else { return nil }
        // The Main UI cuts the list at the first place the current page appears, so an earlier
        // copy of it would quietly throw away everything after that.
        let withoutEarlierCopies = pages.dropLast().filter { $0 != last } + [last]
        // Removing pages can leave the same page sitting next to itself.
        let history = withoutEarlierCopies.reduce(into: [String]()) { result, url in
            if result.last != url { result.append(url) }
        }
        return (Array(history.suffix(maxSeededEntries)), last)
    }

    static func isAdminPath(_ url: String) -> Bool {
        let path = url.split(separator: "?", maxSplits: 1).first.map(String.init) ?? url
        return adminPrefixes.contains { path == $0 || path.hasPrefix($0 + "/") }
    }
}
