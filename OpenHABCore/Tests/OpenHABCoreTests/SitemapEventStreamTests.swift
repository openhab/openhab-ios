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

private actor Messages {
    private(set) var disconnections = 0

    func append(_ message: StreamOutput<SitemapEventMessage>) {
        if case .disconnected = message {
            disconnections += 1
        }
    }
}

/// Holds each event request open until it is cancelled, then fails it the way LoggingMiddleware
/// does: with an error that isn't a `CancellationError`.
private actor WaitingEventsService: OpenAPIServiceProtocol {
    struct Unused: Error {}

    private(set) var requests = 0

    func openHABcreateSubscription() -> String? {
        "subscription"
    }

    func openHABSitemapWidgetEvents(subscriptionid: String, sitemap: String, pageId: String)
        async throws -> any AsyncSequence<SitemapEventMessage, any Error> & Sendable {
        requests += 1
        try? await Task.sleep(for: .seconds(60))
        throw URLError(.badServerResponse)
    }

    func getRootVersion() throws -> Int {
        throw Unused()
    }

    func getRoot() throws -> OpenHABServerProperties {
        throw Unused()
    }

    func sendItemCommand(itemname: String, command: String, sourcePrefix: String?, deviceId: String?) throws {
        throw Unused()
    }

    func updateItemState(itemname: String, with: String, sourcePrefix: String?, deviceId: String?) throws {
        throw Unused()
    }

    func getItems() throws -> [OpenHABItem] {
        throw Unused()
    }

    func getItems(query: Operations.getItems.Input.Query) throws -> [OpenHABItem] {
        throw Unused()
    }

    func getItemByName(id: String) throws -> OpenHABItem? {
        throw Unused()
    }

    func pollDataForPage(sitemapname: String, pageId: String, longPolling: Bool) throws -> OpenHABPage? {
        throw Unused()
    }

    func runNow(ruleUID: String, payload: [String: any Sendable]) throws {
        throw Unused()
    }

    func openHABEvents(topics: String?) throws -> any AsyncSequence<OpenHABEvent, any Error> & Sendable {
        throw Unused()
    }
}

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

    @Test("A replaced listener doesn't report its cancelled request as a disconnection")
    func cancelledListenerStaysSilent() async throws {
        let service = WaitingEventsService()
        let stream = SitemapEventStream { _ in service }
        await stream.updateConnection(connection("http://local"))
        let messages = Messages()
        let consumer = Task {
            for await message in await stream.stream(sitemap: "home", pageId: "home") {
                await messages.append(message)
            }
        }
        defer { consumer.cancel() }
        try await waitUntil { await service.requests == 1 }

        await stream.updateConnection(connection("http://remote"))
        try await waitUntil { await service.requests == 2 }
        try await Task.sleep(for: .milliseconds(50))

        #expect(await messages.disconnections == 0)
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
