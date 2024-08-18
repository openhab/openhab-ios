// Copyright (c) 2010-2024 Contributors to the openHAB project
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
    func openHABTiles() async throws -> [OpenHABUiTile]
}

// swiftlint:disable file_types_order

public actor APIActor {
    var api: APIProtocol
    var url: URL?
    var longPolling = false
    var alwaysSendBasicAuth = false
    var username: String
    var password: String

    private let logger = Logger(subsystem: "org.openhab.app", category: "apiactor")

    public init(username: String = "", password: String = "", alwaysSendBasicAuth: Bool = true, url: URL = URL(staticString: "about:blank")) async {
        // TODO: Make use of prepareURLSessionConfiguration
        let config = URLSessionConfiguration.default
//        config.timeoutIntervalForRequest = if longPolling { 35.0 } else { 20.0 }
//        config.timeoutIntervalForResource = config.timeoutIntervalForRequest + 25

        let delegate = APIActorDelegate(username: username, password: password)
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        self.username = username
        self.password = password
        self.alwaysSendBasicAuth = alwaysSendBasicAuth
        self.url = url

        api = Client(
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
        if newURL != url {
            let config = prepareURLSessionConfiguration(longPolling: longPolling)
            let session = URLSession(configuration: config)
            url = newURL
            api = Client(
                serverURL: newURL.appending(path: "/rest"),
                transport: URLSessionTransport(configuration: .init(session: session)),
                middlewares: [
                    AuthorisationMiddleware(username: username, password: password),
                    LoggingMiddleware()
                ]
            )
        }
    }

    // timeoutIntervalForRequest/timeoutIntervalForResource need to be passed through URLSessionConfiguration when URLSession is created. Therefore create a new APIClient to change values.
    public func updateForLongPolling(_ newlongPolling: Bool) async {
        if newlongPolling != longPolling {
            let config = prepareURLSessionConfiguration(longPolling: longPolling)
            let session = URLSession(configuration: config)
            longPolling = newlongPolling
            api = Client(
                serverURL: url!.appending(path: "/rest"),
                transport: URLSessionTransport(configuration: .init(session: session)),
                middlewares: [
                    AuthorisationMiddleware(username: username, password: password),
                    LoggingMiddleware()
                ]
            )
        }
    }
}

public enum APIActorError: Error {
    case undocumented
}

extension APIActor: OpenHABSitemapsService {
    public func openHABSitemaps() async throws -> [OpenHABSitemap] {
        // swiftformat:disable:next redundantSelf
        logger.log("Trying to getSitemaps for : \(self.url?.debugDescription ?? "No URL")")
        switch try await api.getSitemaps(.init()) {
        case let .ok(okresponse): return try okresponse.body.json.map(OpenHABSitemap.init)
        case .undocumented: throw APIActorError.undocumented
        }
    }
}

extension APIActor: OpenHABUiTileService {
    public func openHABTiles() async throws -> [OpenHABUiTile] {
        try await api.getUITiles(.init())
            .ok.body.json
            .map(OpenHABUiTile.init)
    }
}

public extension AsyncThrowingStream {
//    func map<Transformed>(_ transform: @escaping (Self.Element) -> Transformed) -> AsyncThrowingStream<Transformed, Error> {
//        AsyncThrowingStream<Transformed, Error> { continuation in
//            Task {
//                for try await element in self {
//                    continuation.yield(transform(element))
//                }
//                continuation.finish()
//            }
//        }
//    }

    func map2<T>(transform: @escaping (Self.Element) -> T) -> AsyncThrowingStream<T, Error> {
        AsyncThrowingStream<T, Error> { continuation in
            let task = Task<Void, Error> {
                for try await element in self {
                    continuation.yield(transform(element))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

public extension APIActor {
    func openHABcreateSubscription() async throws -> String? {
        logger.info("Creating subscription")
        let result = try await api.createSitemapEventSubscription()
        guard let urlString = try result.ok.body.json.context?.headers?.Location?.first else { return nil }
        return URL(string: urlString)?.lastPathComponent
    }

    func openHABSitemapWidgetEvents(subscriptionid: String, sitemap: String) async throws -> String {
//    AsyncThrowingStream<OpenHABSitemapWidgetEvent,Error> {
        let path = Operations.getSitemapEvents_1.Input.Path(subscriptionid: subscriptionid)
        let query = Operations.getSitemapEvents_1.Input.Query(sitemap: sitemap, pageid: sitemap)
        let stream = try await api.getSitemapEvents_1(path: path, query: query).ok.body.text_event_hyphen_stream.asDecodedServerSentEventsWithJSONData(of: Components.Schemas.SitemapWidgetEvent.self).compactMap { (value) -> OpenHABSitemapWidgetEvent? in
            guard let data = value.data else { return nil }
            return OpenHABSitemapWidgetEvent(data)
        }
//        return stream.map2

        for try await line in stream {
            print(line)
            print("\n")
        }
        return ""

        logger.debug("subscription date received")
    }
}

extension APIActor {
    // Internal function for pollPage
    func openHABpollPage(path: Operations.pollDataForPage.Input.Path,
                         query: Operations.pollDataForPage.Input.Query = .init(),
                         headers: Operations.pollDataForPage.Input.Headers) async throws -> OpenHABPage? {
        let result = try await api.pollDataForPage(path: path, query: query, headers: headers)
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
        let result = try await api.pollDataForSitemap(path: path, query: query, headers: headers)
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

public extension APIActor {
    func openHABUpdateItemState(itemname: String, with state: String) async throws {
        let path = Operations.updateItemState.Input.Path(itemname: itemname)
        let body = Operations.updateItemState.Input.Body.plainText(.init(state))
        let response = try await api.updateItemState(path: path, body: body)
        _ = try response.accepted
    }

    func openHABSendItemCommand(itemname: String, command: String) async throws {
        let path = Operations.sendItemCommand.Input.Path(itemname: itemname)
        let body = Operations.sendItemCommand.Input.Body.plainText(.init(command))
        let response = try await api.sendItemCommand(path: path, body: body)
        _ = try response.ok
    }
}

// MARK: - URLSessionDelegate for Client Certificates and Basic Auth

class APIActorDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    private let username: String
    private let password: String

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await urlSessionInternal(session, task: nil, didReceive: challenge)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await urlSessionInternal(session, task: task, didReceive: challenge)
    }

    private func urlSessionInternal(_ session: URLSession, task: URLSessionTask?, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        os_log("URLAuthenticationChallenge: %{public}@", log: .networking, type: .info, challenge.protectionSpace.authenticationMethod)
        let authenticationMethod = challenge.protectionSpace.authenticationMethod
        switch authenticationMethod {
        case NSURLAuthenticationMethodServerTrust:
            return await handleServerTrust(challenge: challenge)
        case NSURLAuthenticationMethodDefault, NSURLAuthenticationMethodHTTPBasic:
            if let task {
                task.authAttemptCount += 1
                if task.authAttemptCount > 1 {
                    return (.cancelAuthenticationChallenge, nil)
                } else {
                    return await handleBasicAuth(challenge: challenge)
                }
            } else {
                return await handleBasicAuth(challenge: challenge)
            }
        case NSURLAuthenticationMethodClientCertificate:
            return await handleClientCertificateAuth(challenge: challenge)
        default:
            return (.performDefaultHandling, nil)
        }
    }

    private func handleServerTrust(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }
        let credential = URLCredential(trust: serverTrust)
        return (.useCredential, credential)
    }

    private func handleBasicAuth(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let credential = URLCredential(user: username, password: password, persistence: .forSession)
        return (.useCredential, credential)
    }

    private func handleClientCertificateAuth(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let certificateManager = ClientCertificateManager()
        let (disposition, credential) = certificateManager.evaluateTrust(with: challenge)
        return (disposition, credential)
    }
}

extension OpenHABWidget {
    func update(with event: OpenHABSitemapWidgetEvent) {
        
        state = event.state ?? self.state
        icon = event.icon ?? self.icon
        label = event.label ?? self.label
        iconColor = event.iconcolor ?? ""
        labelcolor = event.labelcolor ?? ""
        valuecolor = event.valuecolor ?? ""
        visibility = event.visibility ?? self.visibility
        
        if let enrichedItem = event.enrichedItem {
            if let link = self.item?.link {
                enrichedItem.link = link
            }
            item = enrichedItem
        }
    }
}

class OpenHABSitemapWidgetEvent {
    init(sitemapName: String? = nil, pageId: String? = nil, widgetId: String? = nil, label: String? = nil, labelSource: String? = nil, icon: String? = nil, reloadIcon: Bool? = nil, labelcolor: String? = nil, valuecolor: String? = nil, iconcolor: String? = nil, visibility: Bool? = nil, state: String? = nil, enrichedItem: OpenHABItem? = nil, descriptionChanged: Bool? = nil) {
        self.sitemapName = sitemapName
        self.pageId = pageId
        self.widgetId = widgetId
        self.label = label
        self.labelSource = labelSource
        self.icon = icon
        self.reloadIcon = reloadIcon
        self.labelcolor = labelcolor
        self.valuecolor = valuecolor
        self.iconcolor = iconcolor
        self.visibility = visibility
        self.state = state
        self.enrichedItem = enrichedItem
        self.descriptionChanged = descriptionChanged
    }

    convenience init(_ event: Components.Schemas.SitemapWidgetEvent) {
        self.init(sitemapName: event.sitemapName, pageId: event.pageId, widgetId: event.widgetId, label: event.label, labelSource: event.labelSource, icon: event.icon, reloadIcon: event.reloadIcon, labelcolor: event.labelcolor, valuecolor: event.valuecolor, iconcolor: event.iconcolor, visibility: event.visibility, state: event.state, enrichedItem: OpenHABItem(event.item), descriptionChanged: event.descriptionChanged)
    }

    var sitemapName: String?
    var pageId: String?
    var widgetId: String?
    var label: String?
    var labelSource: String?
    var icon: String?
    var reloadIcon: Bool?
    var labelcolor: String?
    var valuecolor: String?
    var iconcolor: String?
    var visibility: Bool?
    var state: String?
    var enrichedItem: OpenHABItem?
    var descriptionChanged: Bool?
}

extension OpenHABUiTile {
    convenience init(_ tile: Components.Schemas.TileDTO) {
        self.init(name: tile.name.orEmpty, url: tile.url.orEmpty, imageUrl: tile.imageUrl.orEmpty)
    }
}

extension OpenHABSitemap {
    convenience init(_ sitemap: Components.Schemas.SitemapDTO) {
        self.init(
            name: sitemap.name.orEmpty,
            icon: sitemap.icon.orEmpty,
            label: sitemap.label.orEmpty,
            link: sitemap.link.orEmpty,
            page: OpenHABPage(sitemap.homepage)
        )
    }
}

extension OpenHABPage {
    convenience init?(_ page: Components.Schemas.PageDTO?) {
        if let page {
            self.init(
                pageId: page.id.orEmpty,
                title: page.title.orEmpty,
                link: page.link.orEmpty,
                leaf: page.leaf ?? false,
                widgets: page.widgets?.compactMap { OpenHABWidget($0) } ?? [],
                icon: page.icon.orEmpty
            )
        } else {
            return nil
        }
    }
}

extension OpenHABWidgetMapping {
    convenience init(_ mapping: Components.Schemas.MappingDTO) {
        self.init(command: mapping.command, label: mapping.label)
    }
}

extension OpenHABCommandOptions {
    convenience init?(_ options: Components.Schemas.CommandOption?) {
        if let options {
            self.init(command: options.command.orEmpty, label: options.label.orEmpty)
        } else {
            return nil
        }
    }
}

extension OpenHABOptions {
    convenience init?(_ options: Components.Schemas.StateOption?) {
        if let options {
            self.init(value: options.value.orEmpty, label: options.label.orEmpty)
        } else {
            return nil
        }
    }
}

extension OpenHABStateDescription {
    convenience init?(_ state: Components.Schemas.StateDescription?) {
        if let state {
            self.init(minimum: state.minimum, maximum: state.maximum, step: state.step, readOnly: state.readOnly, options: state.options?.compactMap { OpenHABOptions($0) }, pattern: state.pattern)
        } else {
            return nil
        }
    }
}

extension OpenHABCommandDescription {
    convenience init?(_ commands: Components.Schemas.CommandDescription?) {
        if let commands {
            self.init(commandOptions: commands.commandOptions?.compactMap { OpenHABCommandOptions($0) })
        } else {
            return nil
        }
    }
}

// swiftlint:disable line_length
extension OpenHABItem {
    convenience init?(_ item: Components.Schemas.EnrichedItemDTO?) {
        if let item {
            self.init(name: item.name.orEmpty, type: item._type.orEmpty, state: item.state.orEmpty, link: item.link.orEmpty, label: item.label.orEmpty, groupType: nil, stateDescription: OpenHABStateDescription(item.stateDescription), commandDescription: OpenHABCommandDescription(item.commandDescription), members: [], category: item.category, options: [])
        } else {
            return nil
        }
    }
}

// swiftlint:enable line_length

extension OpenHABWidget {
    convenience init(_ widget: Components.Schemas.WidgetDTO) {
        self.init(
            widgetId: widget.widgetId.orEmpty,
            label: widget.label.orEmpty,
            icon: widget.icon.orEmpty,
            type: OpenHABWidget.WidgetType(rawValue: widget._type!),
            url: widget.url,
            period: widget.period,
            minValue: widget.minValue,
            maxValue: widget.maxValue,
            step: widget.step,
            refresh: widget.refresh.map(Int.init),
            height: 50, // TODO:
            isLeaf: true,
            iconColor: widget.iconcolor,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            service: widget.service,
            state: widget.state,
            text: "",
            legend: widget.legend,
            encoding: widget.encoding,
            item: OpenHABItem(widget.item),
            linkedPage: OpenHABPage(widget.linkedPage),
            mappings: widget.mappings?.compactMap(OpenHABWidgetMapping.init) ?? [],
            widgets: widget.widgets?.compactMap { OpenHABWidget($0) } ?? [],
            visibility: widget.visibility,
            switchSupport: widget.switchSupport,
            forceAsItem: widget.forceAsItem
        )
    }
}

// swiftlint:enable file_types_order
