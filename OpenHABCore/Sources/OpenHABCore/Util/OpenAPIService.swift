// Copyright (c) 2010-2025 Contributors to the openHAB project
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

public protocol OpenHABSitemapsService {
    func openHABSitemaps() async throws -> [OpenHABSitemap]
}

public protocol OpenHABUiTileService {
    func getUITiles() async throws -> [OpenHABUiTile]
}

public enum OpenAPIServiceError: Error {
    case undocumented(statusCode: Swift.Int, undocumentedPayload: OpenAPIRuntime.UndocumentedPayload)
    case noRootURL
}

public actor OpenAPIService {
    private var client: Client
    private var url: URL?
    private var longPolling = false

    private let username: String
    private let password: String
    private let alwaysSendBasicAuth: Bool
    private let ignoreSSL: Bool

    private let logger = Logger(subsystem: "org.openhab.app", category: "OpenAPIService")

    public init(
        baseURL url: URL = URL(staticString: "about:blank"),
        username: String,
        password: String,
        alwaysSendBasicAuth: Bool = false,
        ignoreSSL: Bool = false
    ) async {
        // TODO: Make use of prepareURLSessionConfiguration
        let config = URLSessionConfiguration.default
//        config.timeoutIntervalForRequest = if longPolling { 35.0 } else { 20.0 }
//        config.timeoutIntervalForResource = config.timeoutIntervalForRequest + 25

        let delegate = OpenAPIServiceDelegate(username: username, password: password)
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        self.username = username
        self.password = password
        self.alwaysSendBasicAuth = alwaysSendBasicAuth
        self.url = url
        self.ignoreSSL = ignoreSSL

        client = Client(
            serverURL: url.appending(path: "/rest"),
            transport: URLSessionTransport(configuration: .init(session: session)),
            middlewares: [
                AuthorisationMiddleware(username: username, password: password, alwaysSendBasicAuth: alwaysSendBasicAuth),
                LoggingMiddleware()
            ]
        )
    }

    private func prepareURLSessionConfiguration(longPolling: Bool) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
//        config.timeoutIntervalForRequest = if longPolling { 35.0 } else { 20.0 }
//        config.timeoutIntervalForResource = config.timeoutIntervalForRequest + 25
        return config
    }

    public func updateBaseURL(with newURL: URL) async {
        guard newURL != url else { return }
        url = newURL

        let config = prepareURLSessionConfiguration(longPolling: longPolling)
        let session = URLSession(configuration: config)
        client = Client(
            serverURL: newURL.appending(path: "/rest"),
            transport: URLSessionTransport(configuration: .init(session: session)),
            middlewares: [
                AuthorisationMiddleware(username: username, password: password),
                LoggingMiddleware()
            ]
        )
    }

    // timeoutIntervalForRequest/timeoutIntervalForResource need to be passed through URLSessionConfiguration when URLSession is created. Therefore create a new APIClient to change values.
    public func updateForLongPolling(_ newlongPolling: Bool) async {
        guard newlongPolling != longPolling else { return }
        longPolling = newlongPolling

        let config = prepareURLSessionConfiguration(longPolling: longPolling)
        let session = URLSession(configuration: config)
        client = Client(
            serverURL: url!.appending(path: "/rest"),
            transport: URLSessionTransport(configuration: .init(session: session)),
            middlewares: [
                AuthorisationMiddleware(username: username, password: password),
                LoggingMiddleware()
            ]
        )
    }
}

extension OpenAPIService: OpenHABSitemapsService {
    public func openHABSitemaps() async throws -> [OpenHABSitemap] {
        // swiftformat:disable:next redundantSelf
        guard let url else { throw OpenAPIServiceError.noRootURL }

        logger.log("Trying to getSitemaps for : \(url.debugDescription)")
        let response = try await client.getSitemaps(.init())
        switch response {
        case let .ok(okresponse):
            return try okresponse.body.json.map(OpenHABSitemap.init)
        case let .undocumented(statusCode, undocumentedPayload):
            throw OpenAPIServiceError.undocumented(statusCode: statusCode, undocumentedPayload: undocumentedPayload)
        }
    }
}

extension OpenAPIService: OpenHABUiTileService {
    public func getUITiles() async throws -> [OpenHABUiTile] {
        try await client.getUITiles(.init())
            .ok.body.json
            .map(OpenHABUiTile.init)
    }
}

public extension OpenAPIService {
    func getRoot() async throws -> OpenHABServerProperties {
        let result = try await client.getRoot()
            .ok.body.json
        return OpenHABServerProperties(result)
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
    func openHABcreateSubscription() async throws -> String? {
        logger.info("Creating subscription")
        let result = try await client.createSitemapEventSubscription()
        guard let urlString = try result.ok.body.json.context?.headers?.Location?.first else { return nil }
        return URL(string: urlString)?.lastPathComponent
    }

    // Will need swift 6.0 SE-0421 to return an opaque sequence
    func openHABSitemapWidgetEvents(subscriptionid: String, sitemap: String) async throws -> AsyncCompactMapSequence<AsyncThrowingMapSequence<ServerSentEventsDeserializationSequence<ServerSentEventsLineDeserializationSequence<HTTPBody>>, ServerSentEventWithJSONData<Components.Schemas.SitemapWidgetEvent>>, OpenHABSitemapWidgetEvent> {
        let path = Operations.getSitemapEvents_1.Input.Path(subscriptionid: subscriptionid)
        let query = Operations.getSitemapEvents_1.Input.Query(sitemap: sitemap, pageid: sitemap)
        let decodedSequence = try await client.getSitemapEvents_1(path: path, query: query)
            .ok.body.text_event_hyphen_stream
            .asDecodedServerSentEventsWithJSONData(of: Components.Schemas.SitemapWidgetEvent.self)
        return decodedSequence.compactMap { OpenHABSitemapWidgetEvent($0.data) }
    }
}

extension OpenAPIService {
    // Internal function for pollPage
    func openHABpollPage(path: Operations.pollDataForPage.Input.Path,
                         query: Operations.pollDataForPage.Input.Query = .init(),
                         headers: Operations.pollDataForPage.Input.Headers) async throws -> OpenHABPage? {
        let result = try await client.pollDataForPage(path: path, query: query, headers: headers)
            .ok.body.json
        return OpenHABPage(result)
    }

    /// Poll page data on sitemap
    /// - Parameters:
    ///   - sitemapname: name of sitemap
    ///   - longPolling: set to true for long-polling
    public func openHABpollPage(sitemapname: String, longPolling: Bool) async throws -> OpenHABPage? {
        var headers = Operations.pollDataForPage.Input.Headers()
        if longPolling {
            logger.info("Long-polling, setting X-Atmosphere-Transport")
            headers.X_hyphen_Atmosphere_hyphen_Transport = "long-polling"
        } else {
            headers.X_hyphen_Atmosphere_hyphen_Transport = nil
        }
        let path = Operations.pollDataForPage.Input.Path(sitemapname: sitemapname, pageid: sitemapname)
        await updateForLongPolling(longPolling)
        return try await openHABpollPage(path: path, headers: headers)
    }

    // Internal function for pollSitemap
    func openHABpollSitemap(path: Operations.pollDataForSitemap.Input.Path,
                            query: Operations.pollDataForSitemap.Input.Query = .init(),
                            headers: Operations.pollDataForSitemap.Input.Headers) async throws -> OpenHABSitemap? {
        let result = try await client.pollDataForSitemap(path: path, query: query, headers: headers)
            .ok.body.json
        return OpenHABSitemap(result)
    }

    public func openHABpollSitemap(sitemapname: String, longPolling: Bool, subscriptionId: String? = nil) async throws -> OpenHABSitemap? {
        var headers = Operations.pollDataForSitemap.Input.Headers()
        if longPolling {
            logger.info("Long-polling, setting X-Atmosphere-Transport")
            headers.X_hyphen_Atmosphere_hyphen_Transport = "long-polling"
        } else {
            headers.X_hyphen_Atmosphere_hyphen_Transport = nil
        }
        let query = Operations.pollDataForSitemap.Input.Query(subscriptionid: subscriptionId)
        let path = Operations.pollDataForSitemap.Input.Path(sitemapname: sitemapname)
        await updateForLongPolling(longPolling)
        return try await openHABpollSitemap(path: path, query: query, headers: headers)
    }
}

// MARK: State changes and commands

public extension OpenAPIService {
    func openHABUpdateItemState(itemname: String, with state: String) async throws {
        let path = Operations.updateItemState.Input.Path(itemname: itemname)
        let body = Operations.updateItemState.Input.Body.plainText(.init(state))
        let response = try await client.updateItemState(path: path, body: body)
        _ = try response.accepted
    }

    func openHABSendItemCommand(itemname: String, command: String) async throws {
        let path = Operations.sendItemCommand.Input.Path(itemname: itemname)
        let body = Operations.sendItemCommand.Input.Body.plainText(.init(command))
        let response = try await client.sendItemCommand(path: path, body: body)
        _ = try response.ok
    }
}
