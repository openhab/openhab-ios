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

/// The pages the user visited in the Main UI, so we can put them back there later.
///
/// The Main UI already remembers this, but in browser storage tied to the server address. The
/// local and remote addresses differ, so switching between them loses it. This copy survives.
public struct WebRouteSnapshot: Codable, Equatable, Sendable {
    /// Older than this and we leave the user where they land. It would surprise more than help.
    public static let maxAge: TimeInterval = 7 * 24 * 60 * 60

    /// The pages visited, oldest first. Popups and the like are already left out, they show up
    /// in the address but the Main UI cannot reopen them directly.
    public let history: [String]
    /// The page the user is on. Always the last one in `history`.
    public let url: String
    /// Which server address these were visited on, so we can tell whether we are putting them
    /// back on a different one. No username or password is kept here.
    public let connectionURL: String
    public let capturedAt: Date

    public init(history: [String], url: String, connectionURL: String, capturedAt: Date = Date()) {
        self.history = history
        self.url = url
        self.connectionURL = connectionURL
        self.capturedAt = capturedAt
    }

    /// A date in the future means the clock was set back. Count that as too old, or it would
    /// stay valid until the clock catches up again.
    public func isFresh(now: Date = Date()) -> Bool {
        let age = now.timeIntervalSince(capturedAt)
        return age >= 0 && age < Self.maxAge
    }
}
