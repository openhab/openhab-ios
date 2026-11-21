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

@testable import openHAB
import OpenHABCore
import Testing

@MainActor
struct SitemapDiagnosticsTests {
    @Test(arguments: ["manual", "connection-changed"])
    func classifiesRootInitialLoadAsColdStart(reason: String) {
        let context = SitemapDiagnostics.initialLoadContext(
            reason: reason,
            isLinkedPage: false,
            hasCurrentPage: false
        )

        #expect(context == "coldStart")
    }

    @Test
    func classifiesForegroundRefreshSeparately() {
        let context = SitemapDiagnostics.initialLoadContext(
            reason: "scene-became-active",
            isLinkedPage: false,
            hasCurrentPage: true
        )

        #expect(context == "foregroundResume")
    }

    @Test
    func keepsWarmManualReloadContext() {
        let context = SitemapDiagnostics.initialLoadContext(
            reason: "manual",
            isLinkedPage: false,
            hasCurrentPage: true
        )

        #expect(context == "manual")
    }

    @Test
    func classifiesLinkedPageSeparately() {
        let context = SitemapDiagnostics.initialLoadContext(
            reason: "manual",
            isLinkedPage: true,
            hasCurrentPage: false
        )

        #expect(context == "linkedPage")
    }

    @Test(arguments: [
        (supportsNotifications: true, priority: 1, expected: "cloud"),
        (supportsNotifications: false, priority: 0, expected: "local"),
        (supportsNotifications: false, priority: 1, expected: "remote")
    ])
    func classifiesConnectionKind(supportsNotifications: Bool,
                                  priority: Int,
                                  expected: String) {
        // isCloudConnection currently derives from supportsNotifications.
        let configuration = ConnectionConfiguration(
            url: "https://example.invalid",
            username: "",
            password: "",
            supportsNotifications: supportsNotifications,
            priority: priority
        )

        #expect(SitemapDiagnostics.connectionKind(for: configuration) == expected)
    }
}
