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

public func basicAuthHeader(username: String, password: String) -> String {
    let credential = Data("\(username):\(password)".utf8).base64EncodedString()
    return "Basic \(credential)"
}

public struct AuthorisationMiddleware {
    private let username: String
    private let password: String
    private let alwaysSendBasicAuth: Bool
    private let configuration: ConnectionConfiguration

    public init(configuration: ConnectionConfiguration) {
        username = configuration.username
        password = configuration.password
        alwaysSendBasicAuth = configuration.alwaysSendBasicAuth
        self.configuration = configuration
    }
}

extension AuthorisationMiddleware: ClientMiddleware {
    public func intercept(_ request: HTTPRequest,
                          body: HTTPBody?,
                          baseURL: URL,
                          operationID: String,
                          next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)) async throws -> (HTTPResponse, HTTPBody?) {
        // Use a mutable copy of request
        var newRequest = request
        if configuration.isCloudConnection || alwaysSendBasicAuth, !username.isEmpty, !password.isEmpty {
            newRequest.headerFields[.authorization] = basicAuthHeader(username: username, password: password)
        }
        let (response, body) = try await next(newRequest, body, baseURL)
        return (response, body)
    }
}
