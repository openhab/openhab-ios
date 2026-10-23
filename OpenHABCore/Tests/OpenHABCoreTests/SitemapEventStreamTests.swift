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
@testable import OpenHABCore
import Testing

struct SitemapEventStreamTests {
    @Test("A network change reconnects the stream while someone reads it")
    func reconnectsWithConsumer() async throws {
        let stream = SitemapEventStream { _ in throw URLError(.notConnectedToInternet) }
        await stream.updateConnection(connection("http://local"))
        let consumer = Task { for await _ in await stream.stream(sitemap: "home", pageId: "home") {} }
        defer { consumer.cancel() }
        try await waitUntil { await stream.isListening }

        await stream.updateConnection(connection("http://remote"))

        #expect(await stream.isListening)
    }

    @Test("A network change doesn't reopen the stream once the last consumer has left")
    func staysClosedWithoutConsumers() async throws {
        let stream = SitemapEventStream { _ in throw URLError(.notConnectedToInternet) }
        await stream.updateConnection(connection("http://local"))
        let consumer = Task { for await _ in await stream.stream(sitemap: "home", pageId: "home") {} }
        try await waitUntil { await stream.isListening }
        consumer.cancel()
        try await waitUntil { await !stream.hasConsumers }
        try await waitUntil { await !stream.isListening }

        await stream.updateConnection(connection("http://remote"))

        #expect(await !stream.isListening)
    }

    private func connection(_ url: String) -> ConnectionInfo {
        ConnectionInfo(configuration: ConnectionConfiguration(url: url, username: "", password: "", priority: 0), version: 3)
    }

    private func waitUntil(_ condition: () async -> Bool) async throws {
        for _ in 0 ..< 200 {
            if await condition() {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Condition not met within 2 seconds")
    }
}
