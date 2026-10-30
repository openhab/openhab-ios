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

/// Remembers the widget events that arrive while page reloads are in flight.
///
/// A reloaded page may have been captured before those events, so showing it would bring back
/// stale states. Applying the events again on top of it ends on the newest state either way,
/// since each event carries the state it changed to.
public struct SitemapEventReplayLog {
    /// Marks where in the log a reload began.
    public struct Reload {
        fileprivate let start: Int
    }

    private var events: [OpenHABSitemapWidgetEvent] = []
    private var reloadsInFlight = 0

    public init() {}

    public mutating func beginReload() -> Reload {
        reloadsInFlight += 1
        return Reload(start: events.count)
    }

    /// Keeps the event if a reload is in flight.
    public mutating func record(_ event: OpenHABSitemapWidgetEvent) {
        guard reloadsInFlight > 0 else { return }
        events.append(event)
    }

    /// Ends the reload and returns the events that arrived since it began, oldest first.
    @discardableResult
    public mutating func endReload(_ reload: Reload) -> [OpenHABSitemapWidgetEvent] {
        let missed = Array(events[min(reload.start, events.count)...])
        reloadsInFlight = max(reloadsInFlight - 1, 0)
        if reloadsInFlight == 0 {
            events.removeAll()
        }
        return missed
    }
}
