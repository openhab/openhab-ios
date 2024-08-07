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

//
//  File.swift
//
//
//  Created by Tim on 10.08.24.
//
import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession
import os

let logger = Logger(subsystem: "org.openhab.app", category: "apiactor")

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

    public init(username: String = "", password: String = "", alwaysSendBasicAuth: Bool = true) {
        let url = "about:blank"
        // TODO: Make use of prepareURLSessionConfiguration
        let config = URLSessionConfiguration.default
//        config.timeoutIntervalForRequest = if longPolling { 35.0 } else { 20.0 }
//        config.timeoutIntervalForResource = config.timeoutIntervalForRequest + 25
        let session = URLSession(configuration: config)
        self.username = username
        self.password = password
        self.alwaysSendBasicAuth = alwaysSendBasicAuth

        api = Client(
            serverURL: URL(string: url)!,
            transport: URLSessionTransport(configuration: .init(session: session)),
            middlewares: [AuthorisationMiddleware(username: username, password: password, alwaysSendBasicAuth: alwaysSendBasicAuth)]
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
                middlewares: [AuthorisationMiddleware(username: username, password: password)]
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
                middlewares: [AuthorisationMiddleware(username: username, password: password)]
            )
        }
    }
}

extension APIActor: OpenHABSitemapsService {
    public func openHABSitemaps() async throws -> [OpenHABSitemap] {
        try await api.getSitemaps(.init())
            .ok.body.json
            .map(OpenHABSitemap.init)
    }
}

extension APIActor: OpenHABUiTileService {
    public func openHABTiles() async throws -> [OpenHABUiTile] {
        try await api.getUITiles(.init())
            .ok.body.json
            .map(OpenHABUiTile.init)
    }
}

extension APIActor {
    func openHABSitemap(path: Operations.getSitemapByName.Input.Path) async throws -> OpenHABSitemap? {
        let result = try await api.getSitemapByName(path: path)
            .ok.body.json
        return OpenHABSitemap(result)
    }
}

extension APIActor {
    // Internal function for pollPage
    func openHABpollPage(path: Operations.pollDataForPage.Input.Path,
                         headers: Operations.pollDataForPage.Input.Headers) async throws -> OpenHABPage? {
        let result = try await api.pollDataForPage(path: path, headers: headers)
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
}

extension APIActor {
    func openHABSitemap(path: Operations.getSitemapByName.Input.Path,
                        headers: Operations.getSitemapByName.Input.Headers) async throws -> OpenHABSitemap? {
        let result = try await api.getSitemapByName(path: path, headers: headers)
            .ok.body.json
        return OpenHABSitemap(result)
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

public struct AuthorisationMiddleware {
    private let username: String
    private let password: String
    private let alwaysSendBasicAuth: Bool

    public init(username: String, password: String, alwaysSendBasicAuth: Bool = false) {
        self.username = username
        self.password = password
        self.alwaysSendBasicAuth = alwaysSendBasicAuth
    }
}

extension AuthorisationMiddleware: ClientMiddleware {
    private func basicAuthHeader() -> String {
        let credential = Data("\(username):\(password)".utf8).base64EncodedString()
        return "Basic \(credential)"
    }

    public func intercept(_ request: HTTPRequest,
                          body: HTTPBody?,
                          baseURL: URL,
                          operationID: String,
                          next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)) async throws -> (HTTPResponse, HTTPBody?) {
        // Use a mutable copy of request
        var request = request

        if ((baseURL.host?.hasSuffix("myopenhab.org")) == nil), alwaysSendBasicAuth, !username.isEmpty, !password.isEmpty {
            request.headerFields[.authorization] = basicAuthHeader()
        }
        logger.info("Outgoing request: \(request.headerFields.debugDescription, privacy: .public)")
        let (response, body) = try await next(request, body, baseURL)
        logger.debug("Incoming response \(response.headerFields.debugDescription)")
        return (response, body)
    }
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
