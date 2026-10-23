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

@testable import OpenHABCore
import Testing

struct SitemapEventReplayLogTests {
    @Test("Ignores events while no reload is in flight")
    func ignoresEventsWithoutReload() {
        var log = SitemapEventReplayLog()
        log.record(event("before"))
        let reload = log.beginReload()
        #expect(log.endReload(reload).isEmpty)
    }

    @Test("Returns the events that arrived during a reload, oldest first")
    func returnsEventsDuringReload() {
        var log = SitemapEventReplayLog()
        let reload = log.beginReload()
        log.record(event("ON"))
        log.record(event("OFF"))
        #expect(log.endReload(reload).map(\.state) == ["ON", "OFF"])
    }

    @Test("A reload gets only the events since it began, even while an older one is still in flight")
    func overlappingReloads() {
        var log = SitemapEventReplayLog()
        let older = log.beginReload()
        log.record(event("first"))
        let newer = log.beginReload()
        log.record(event("second"))

        #expect(log.endReload(older).map(\.state) == ["first", "second"])
        log.record(event("third"))
        #expect(log.endReload(newer).map(\.state) == ["second", "third"])
    }

    @Test("Forgets the events once every reload has ended")
    func forgetsAfterLastReload() {
        var log = SitemapEventReplayLog()
        let first = log.beginReload()
        log.record(event("ON"))
        log.endReload(first)

        let next = log.beginReload()
        #expect(log.endReload(next).isEmpty)
    }

    private func event(_ state: String) -> OpenHABSitemapWidgetEvent {
        OpenHABSitemapWidgetEvent(widgetId: "0000", state: state)
    }
}
