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
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession
import os

public enum OpenAPIServiceError: Error {
    case undocumented(statusCode: Int, undocumentedPayload: OpenAPIRuntime.UndocumentedPayload)
    case noRootURL
    case badRequest
    case notFound
    case unAuthorized
}

public enum OpenAPIServiceConfiguration {
    case asDefault
    case shortTerm
    case longTerm
}

protocol OpenAPIServiceProtocol: AnyObject, Sendable {
    func getRootVersion() async throws -> Int
    @discardableResult func getRoot() async throws -> OpenHABServerProperties
    func sendItemCommand(itemname: String, command: String, sourcePrefix: String?, deviceId: String?) async throws
    func updateItemState(itemname: String, with: String, sourcePrefix: String?, deviceId: String?) async throws
    func getItems() async throws -> [OpenHABItem]
    func getItems(query: Operations.getItems.Input.Query) async throws -> [OpenHABItem]
    func getItemByName(id: String) async throws -> OpenHABItem?
    func pollDataForPage(sitemapname: String, pageId: String, longPolling: Bool) async throws -> OpenHABPage?
    func runNow(ruleUID: String, payload: [String: any Sendable]) async throws
}

/// The generated OpenAPI client is wrapped by this curated API.
/// The library leaks the fact that it uses Swift OpenAPI Generator under the hood for SSE streams.
/// It will require the migration to Swift 6.1 before this can be changed.
public actor OpenAPIService {
    private var client: any APIProtocol
    private var url: URL?
    private var longPolling = false
    private var connectionConfiguration: ConnectionConfiguration
    /// Retained for lifecycle control only — URLSessionTransport does not call invalidateAndCancel()
    /// when it deallocates, so without this reference the session's threads and sockets would leak.
    /// Do not remove: deinit relies on this property to tear down the session.
    private var urlSession: URLSession?

    /// Creates a new client for OpenAPIService.
    public init(client: any APIProtocol) {
        self.client = client
        connectionConfiguration = ConnectionConfiguration(url: "", username: "", password: "")
    }

    public init(connectionConfiguration: ConnectionConfiguration,
                serviceConfiguration: OpenAPIServiceConfiguration = .asDefault) throws {
        guard !connectionConfiguration.url.isEmpty else {
            throw OpenHABSitemapError.invalidConnectionConfiguration
        }
        self.connectionConfiguration = connectionConfiguration
        let delegate = HTTPClientDelegate(with: connectionConfiguration)
        let config = URLSessionConfiguration.default
        switch serviceConfiguration {
        case .asDefault:
            break
        case .longTerm:
            // Watch sitemap polling must bypass URL cache to avoid serving stale
            // pages after periods of inactivity.
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            config.urlCache = nil
            config.timeoutIntervalForRequest = 35.0
            config.timeoutIntervalForResource = config.timeoutIntervalForRequest + 25
        case .shortTerm:
            config.timeoutIntervalForRequest = 10.0
            config.timeoutIntervalForResource = 10.0
        }
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        urlSession = session
        let url = URL(string: connectionConfiguration.url) ?? URL(staticString: "about:blank")
        let resolvedURL = OpenAPIService.getServerURL(for: url)
        self.url = resolvedURL

        let serverURL = resolvedURL.appending(path: "/rest")

        client = Client(
            serverURL: serverURL,
            configuration: .init(dateTranscoder: ISO8601DateTranscoder(options: [.withInternetDateTime, .withFractionalSeconds, .withTimeZone, .withColonSeparatorInTimeZone])),
            transport: URLSessionTransport(configuration: .init(session: session)),
            middlewares: [
                LoggingMiddleware(),
                AuthorisationMiddleware(configuration: connectionConfiguration)
            ]
        )
    }

    private static func getServerURL(for url: URL) -> URL {
        // Respect the configured connection URL. Forcing cloud hosts can fail
        // DNS resolution on some networks/simulators and breaks sitemap loading.
        url
    }

    private func prepareURLSessionConfiguration(longPolling: Bool) -> URLSessionConfiguration {
        URLSessionConfiguration.default
//        config.timeoutIntervalForRequest = if longPolling { 35.0 } else { 20.0 }
//        config.timeoutIntervalForResource = config.timeoutIntervalForRequest + 25
    }

    private func sourceComponent(deviceId: String?) -> String? {
        #if os(watchOS)
        let base = "org.openhab.watchos"
        #else
        let base = "org.openhab.ios"
        #endif
        guard let deviceId else { return base }
        let trimmed = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        // Actor must not include the delegation separator per openHAB source spec.
        if trimmed.isEmpty || trimmed.contains("=>") {
            return base
        }
        return "\(base)$\(trimmed)"
    }

    private func buildSource(sourcePrefix: String?, deviceId: String?) -> String? {
        let base = sourceComponent(deviceId: deviceId)
        guard let sourcePrefix, !sourcePrefix.isEmpty else { return base }
        guard let base else { return sourcePrefix }
        return "\(sourcePrefix)=>\(base)"
    }

    private func subscriptionId(from location: String?) -> String? {
        guard let location else { return nil }
        return URL(string: location)?.lastPathComponent
    }

    deinit {
        urlSession?.invalidateAndCancel()
    }
}

public extension OpenAPIService {
    func openHABSitemaps() async throws -> [OpenHABSitemap] {
        // swiftformat:disable:next redundantSelf
        guard let url else { throw OpenAPIServiceError.noRootURL }

        Logger.openAPIService.log("Trying to getSitemaps for: \(url.debugDescription, privacy: .public)")
        let response = try await client.getSitemaps(.init())
        switch response {
        case let .ok(okresponse):
            return try okresponse.body.json.map(OpenHABSitemap.init)
        case let .undocumented(statusCode, undocumentedPayload):
            throw OpenAPIServiceError.undocumented(statusCode: statusCode, undocumentedPayload: undocumentedPayload)
        }
    }
}

public extension OpenAPIService {
    func getUITiles() async throws -> [OpenHABUiTile] {
        try await client.getUITiles(.init())
            .ok.body.json
            .map(OpenHABUiTile.init)
    }
}

public extension OpenAPIService {
    @discardableResult
    func getRoot() async throws -> OpenHABServerProperties {
        let response = try await client.getRoot()
        switch response {
        case let .ok(okresponse):
            let result = try okresponse.body.json
            return OpenHABServerProperties(result)
        case .unauthorized:
            throw OpenAPIServiceError.unAuthorized
        case let .undocumented(statusCode, undocumentedPayload):
            throw OpenAPIServiceError.undocumented(statusCode: statusCode, undocumentedPayload: undocumentedPayload)
        }
    }

    @discardableResult
    func getRootVersion() async throws -> Int {
        let serverProperties = try await getRoot()
        guard let version = Int(serverProperties.version ?? "0"),
              version > 1 else {
            throw NetworkTrackerError.invalidServerVersion
        }
        return version
    }
}

public extension OpenAPIService {
    func getItemByName(id: String) async throws -> OpenHABItem? {
        let path = Operations.getItemByName.Input.Path(itemname: id)
        let result = try await client.getItemByName(path: path)
            .ok.body.json
        return OpenHABItem(result)
    }
}

public extension OpenAPIService {
    func runNow(ruleUID: String, payload: [String: any Sendable]) async throws {
        let path = Operations.runRuleNow_1.Input.Path(ruleUID: ruleUID)
        let jsonPayload = try Operations.runRuleNow_1.Input.Body.jsonPayload(
            additionalProperties: OpenAPIObjectContainer(unvalidatedValue: payload)
        )
        _ = try await client.runRuleNow_1(
            path: path,
            body: .json(jsonPayload)
        )
    }
}

public extension OpenAPIService {
    // Will need swift 6.0 SE-0421 and iOS 18 to return an opaque sequence without the type eraser AnyAsyncSequence<Element>
    /// Type-erased async sequence wrapper.
    ///
    /// This type is marked `@unchecked Sendable` when `Element: Sendable` because:
    /// - The wrapped iterator closure captures a mutable iterator, which isn't inherently Sendable
    /// - However, the iterator is only accessed sequentially via `next()` calls
    /// - The element type constraint ensures values crossing actor boundaries are safe
    struct AnyAsyncSequence<Element: Sendable>: AsyncSequence {
        public struct Iterator: AsyncIteratorProtocol {
            private var _next: () async throws -> Element?

            init<S: AsyncSequence>(_ base: S) where S.Element == Element {
                var it = base.makeAsyncIterator()
                _next = { try await it.next() }
            }

            public mutating func next() async throws -> Element? {
                try await _next()
            }
        }

        public let _make: () -> Iterator

        init<S: AsyncSequence>(_ base: S) where S.Element == Element {
            _make = { Iterator(base) }
        }

        public func makeAsyncIterator() -> Iterator {
            _make()
        }
    }

    /// Returns subscription id or nil
    func openHABcreateSubscription() async throws -> String? {
        Logger.openAPIService.info("Creating subscription")
        guard let acceptValue = OpenAPIRuntime.AcceptHeaderContentType<Operations.createSitemapEventSubscription.AcceptableContentType>(rawValue: "application/json") else {
            return nil
        }
        let accept: [OpenAPIRuntime.AcceptHeaderContentType<Operations.createSitemapEventSubscription.AcceptableContentType>] = [
            acceptValue
        ]
        let headers = Operations.createSitemapEventSubscription.Input.Headers(accept: accept)
        let result = try await client.createSitemapEventSubscription(.init(headers: headers))

        switch result {
        case let .ok(ok):
            // openHAB < 3.3: returns 200 with Location in JSON body.
            guard let urlString = try ok.body.json.context?.headers?.Location?.first else { return nil }
            let subscriptionId = subscriptionId(from: urlString)
            Logger.openAPIService.info("Sitemap SSE subscription created from JSON body: \(subscriptionId.orEmpty, privacy: .public)")
            return subscriptionId
        case let .created(created):
            // openHAB >= 3.3: returns 201 with Location in the HTTP header.
            let subscriptionId = subscriptionId(from: created.headers.Location)
            Logger.openAPIService.info("Sitemap SSE subscription created from Location header: \(subscriptionId.orEmpty, privacy: .public)")
            return subscriptionId
        case .serviceUnavailable:
            // Subscriptions limit reached on the server.
            Logger.openAPIService.warning("Sitemap SSE subscription limit reached (503) — server has too many open subscriptions")
            throw URLError(.badServerResponse)
        default:
            Logger.openAPIService.warning("Sitemap SSE subscription returned unexpected response")
            throw URLError(.badServerResponse)
        }
    }

    /// The app still supports iOS 16+, so keep this type-erased instead of
    /// returning an opaque AsyncSequence. Raw ServerSentEvent access is also
    /// needed for ALIVE, SITEMAP_CHANGED, and widget payloads.
    func openHABSitemapWidgetEventsRaw(subscriptionid: String, sitemap: String, pageId: String)
        async throws -> AnyAsyncSequence<ServerSentEvent> {
        let path = Operations.getSitemapEvents_1.Input.Path(subscriptionid: subscriptionid)
        let query = Operations.getSitemapEvents_1.Input.Query(sitemap: sitemap, pageid: pageId)

        let seq = try await client.getSitemapEvents_1(path: path, query: query)
            .ok.body.text_event_hyphen_stream
            .asDecodedServerSentEvents()

        return AnyAsyncSequence(seq)
    }

    func openHABEvents(topics: String? = nil)
        async throws -> AnyAsyncSequence<OpenHABEvent> {
        let query: Operations.getEvents.Input.Query =
            (topics == nil) ? .init() : .init(topics: topics)

        let seq = try await client.getEvents(query: query)
            .ok.body.text_event_hyphen_stream
            .asDecodedServerSentEventsWithJSONData(of: OpenHABEvent.self)
            .compactMap(\.data)

        return AnyAsyncSequence(seq)
    }
}

public extension OpenAPIService {
    /// Internal function for pollPage
    internal func pollDataForPage(path: Operations.pollDataForPage.Input.Path,
                                  query: Operations.pollDataForPage.Input.Query = .init(),
                                  headers: Operations.pollDataForPage.Input.Headers) async throws -> OpenHABPage? {
        let response = try await client.pollDataForPage(path: path, query: query, headers: headers)
        switch response {
        case let .ok(okresponse):
            let result = try okresponse.body.json
            return OpenHABPage(result)
        case let .undocumented(statusCode, undocumentedPayload):
            throw OpenAPIServiceError.undocumented(statusCode: statusCode, undocumentedPayload: undocumentedPayload)
        case .badRequest:
            throw OpenAPIServiceError.badRequest
        case .notFound:
            throw OpenAPIServiceError.notFound
        }
    }

    /// Poll page data on sitemap
    /// - Parameters:
    ///   - sitemapname: name of sitemap
    ///   - pageId: id of subpage
    ///   - longPolling: set to true for long-polling
    func pollDataForPage(sitemapname: String, pageId: String = "", longPolling: Bool) async throws -> OpenHABPage? {
        var headers = Operations.pollDataForPage.Input.Headers()
        if longPolling {
            Logger.openAPIService.info("Setting header X-Atmosphere-Transport to long-polling")
            headers.X_hyphen_Atmosphere_hyphen_Transport = "long-polling"
        }
        let path = if pageId.isEmpty {
            Operations.pollDataForPage.Input.Path(sitemapname: sitemapname, pageid: sitemapname)
        } else {
            Operations.pollDataForPage.Input.Path(sitemapname: sitemapname, pageid: pageId)
        }
        //        logger.debug("pollDataForPage: :\(String(describing: headers)), \(String(describing: path))")
        return try await pollDataForPage(path: path, headers: headers)
    }

    /// Internal function for pollSitemap
    internal func pollDataForSitemap(path: Operations.pollDataForSitemap.Input.Path,
                                     query: Operations.pollDataForSitemap.Input.Query = .init(),
                                     headers: Operations.pollDataForSitemap.Input.Headers) async throws -> OpenHABSitemap? {
        let result = try await client.pollDataForSitemap(path: path, query: query, headers: headers)
            .ok.body.json
        return OpenHABSitemap(result)
    }
}

/// Array of items
public extension OpenAPIService {
    func getItems(query: Operations.getItems.Input.Query) async throws -> [OpenHABItem] {
        try await client.getItems(query: query)
            .ok.body.json
            .compactMap(OpenHABItem.init)
    }

    func getItems() async throws -> [OpenHABItem] {
        try await getItems(query: .init())
    }
}

public extension OpenAPIService {
    func initNewStateTacker() async throws -> Operations.initNewStateTacker.Output {
        try await client.initNewStateTacker()
    }

    func updateItemListForStateUpdates(connectionId: String, items: [String]) async throws {
        let path = Operations.updateItemListForStateUpdates.Input.Path(connectionId: connectionId)
        let body = Operations.updateItemListForStateUpdates.Input.Body.json(.init(items))
        let response = try await client.updateItemListForStateUpdates(path: path, body: body)
        _ = try response.ok
    }
}

// MARK: State changes and commands

public extension OpenAPIService {
    func updateItemState(itemname: String, with state: String, sourcePrefix: String? = nil, deviceId: String? = nil) async throws {
        let path = Operations.updateItemState.Input.Path(itemname: itemname)
        let body = Operations.updateItemState.Input.Body.plainText(.init(state))
        let query = Operations.updateItemState.Input.Query(source: buildSource(sourcePrefix: sourcePrefix, deviceId: deviceId))
        let response = try await client.updateItemState(path: path, query: query, body: body)
        _ = try response.accepted
    }

    func sendItemCommand(itemname: String, command: String, sourcePrefix: String? = nil, deviceId: String? = nil) async throws {
        let path = Operations.sendItemCommand.Input.Path(itemname: itemname)
        // Use JSON only for empty-string commands: swift-openapi-generator drops an empty
        // text/plain body, but {"value":""} correctly conveys an empty command (e.g., clearing
        // a String item). Non-empty commands use text/plain, which is accepted by all openHAB
        // versions (4.x and 5.x), avoiding a 400 from servers that predate the JSON body format.
        let body: Operations.sendItemCommand.Input.Body = command.isEmpty
            ? .json(.init(value: command))
            : .plainText(.init(command))
        let query = Operations.sendItemCommand.Input.Query(source: buildSource(sourcePrefix: sourcePrefix, deviceId: deviceId))
        let response = try await client.sendItemCommand(path: path, query: query, body: body)
        _ = try response.ok
    }
}

extension OpenAPIService: OpenAPIServiceProtocol {}

extension OpenAPIService.AnyAsyncSequence: @unchecked Sendable {}
