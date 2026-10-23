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

/// How a sitemap page keeps up with the server. Shared by the iPhone and watch apps, so both
/// decide the same way.
///
/// From openHAB 3 the server pushes each widget change as a sitemap event (`SitemapEventStream`).
/// Older servers, and a stream that never connects, fall back to long polling
/// (`SitemapPageLoader`), which can miss a change that lands between two requests.
public enum SitemapUpdatePolicy {
    /// Whether to follow a page through sitemap events, for the server's major version.
    public static func usesEvents(serverVersion: Int?) -> Bool {
        (serverVersion ?? 0) >= 3
    }

    /// Whether to give up on events after the stream dropped: the server can't send them, or the
    /// stream never connected. A stream that was connected reconnects by itself.
    public static func shouldFallBackToLongPolling(after error: (any Error)?, hasConnected: Bool) -> Bool {
        if error is SitemapSseError {
            return true
        }
        return !hasConnected
    }

    /// Whether the page has to be fetched again after a widget event was applied to it.
    public static func needsPageReload(after result: SitemapWidgetEventApplicationResult) -> Bool {
        switch result {
        case .requiresPageReload, .notFound: true
        case .applied, .unchanged: false
        }
    }
}
