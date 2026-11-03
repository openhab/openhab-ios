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

import Observation
@testable import OpenHABCore
import Synchronization
import Testing

/// Each test changes the value it observes: @Observable skips the notification when a property is
/// set to an equal value.
struct OpenHABWidgetObservationTests {
    @Test("Changing the state notifies the views that read it")
    func stateChangeNotifies() {
        let widget = OpenHABWidget(icon: "light")
        widget.state = "OFF"

        let changed = observeChange(of: { _ = widget.state }, by: { widget.state = "ON" })

        #expect(changed)
    }

    @Test("Applying a sitemap event notifies the views that read the widget")
    func eventNotifies() {
        let widget = OpenHABWidget(icon: "light")
        widget.widgetId = "0600"
        widget.state = "OFF"

        let changed = observeChange(of: { _ = widget.state }, by: {
            widget.apply(event: OpenHABSitemapWidgetEvent(widgetId: "0600", state: "ON"))
        })

        #expect(changed)
    }

    @Test("Visibility, which wasn't published before, now notifies too")
    func visibilityChangeNotifies() {
        let widget = OpenHABWidget(icon: "light")

        let changed = observeChange(of: { _ = widget.visibility }, by: { widget.visibility = false })

        #expect(changed)
    }

    @Test("Setting the command handler, done on every page refresh, notifies nobody")
    func sendCommandIsIgnored() {
        let widget = OpenHABWidget(icon: "light")

        let changed = observeChange(of: { _ = widget.sendCommand }, by: { widget.sendCommand = { _, _ in } })

        #expect(!changed)
    }

    private func observeChange(of read: () -> Void, by change: () -> Void) -> Bool {
        let changed = Mutex(false)
        withObservationTracking(read) {
            changed.withLock { $0 = true }
        }
        change()
        return changed.withLock { $0 }
    }
}
