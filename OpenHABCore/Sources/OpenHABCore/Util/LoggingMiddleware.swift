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
import os

// swiftlint:disable file_types_order
package actor LoggingMiddleware {
    private static var defaultLogger: Logger {
        Logger(subsystem: "org.openhab.app", category: "logging-middleware")
    }

    private let logger: Logger
    package let bodyLoggingPolicy: BodyLoggingPolicy

    package init(logger: Logger = defaultLogger, bodyLoggingConfiguration: BodyLoggingPolicy = .never) {
        self.logger = logger
        bodyLoggingPolicy = bodyLoggingConfiguration
    }
}

extension LoggingMiddleware: ClientMiddleware {
    package func intercept(_ request: HTTPRequest,
                           body: HTTPBody?,
                           baseURL: URL,
                           operationID: String,
                           next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)) async throws -> (HTTPResponse, HTTPBody?) {
        let (requestBodyToLog, requestBodyForNext) = try await bodyLoggingPolicy.process(body)
        log(request, requestBodyToLog)
        do {
            let (response, responseBody) = try await next(request, requestBodyForNext, baseURL)
            let (responseBodyToLog, responseBodyForNext) = try await bodyLoggingPolicy.process(responseBody)
            log(request, response, responseBodyToLog)
            return (response, responseBodyForNext)
        } catch {
            log(request, failedWith: error)
            throw error
        }
    }
}

extension LoggingMiddleware {
    func log(_ request: HTTPRequest, _ requestBody: BodyLoggingPolicy.BodyLog) {
        logger.debug(
            "Request: \(request.method, privacy: .public) \(request.path ?? "<nil>", privacy: .public) body: \(requestBody, privacy: .auto)"
        )
    }

    func log(_ request: HTTPRequest, _ response: HTTPResponse, _ responseBody: BodyLoggingPolicy.BodyLog) {
        logger.debug(
            "Response: \(request.method, privacy: .public) \(request.path ?? "<nil>", privacy: .public) \(response.status, privacy: .public) body: \(responseBody, privacy: .auto)"
        )
    }

    func log(_ request: HTTPRequest, failedWith error: any Error) {
        logger.warning("Request failed. Error: \(error.localizedDescription)")
    }
}

// swiftlint:enable file_types_order

package enum BodyLoggingPolicy {
    /// Never log request or response bodies.
    case never
    /// Log request and response bodies that have a known length less than or equal to `maxBytes`.
    case upTo(maxBytes: Int)

    enum BodyLog: Equatable, CustomStringConvertible {
        /// There is no body to log.
        case none
        /// The policy forbids logging the body.
        case redacted
        /// The body was of unknown length.
        case unknownLength
        /// The body exceeds the maximum size for logging allowed by the policy.
        case tooManyBytesToLog(Int64)
        /// The body can be logged.
        case complete(Data)

        var description: String {
            switch self {
            case .none: return "<none>"
            case .redacted: return "<redacted>"
            case .unknownLength: return "<unknown length>"
            case let .tooManyBytesToLog(byteCount): return "<\(byteCount) bytes>"
            case let .complete(data):
                if let string = String(data: data, encoding: .utf8) { return string }
                return String(describing: data)
            }
        }
    }

    func process(_ body: HTTPBody?) async throws -> (bodyToLog: BodyLog, bodyForNext: HTTPBody?) {
        switch (body?.length, self) {
        case (.none, _): return (.none, body)
        case (_, .never): return (.redacted, body)
        case (.unknown, _): return (.unknownLength, body)
        case let (.known(length), .upTo(maxBytesToLog)) where length > maxBytesToLog:
            return (.tooManyBytesToLog(length), body)
        case let (.known, .upTo(maxBytesToLog)):
            let bodyData = try await Data(collecting: body!, upTo: maxBytesToLog)
            return (.complete(bodyData), HTTPBody(bodyData))
        }
    }
}
