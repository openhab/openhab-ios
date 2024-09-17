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
        if baseURL.host?.hasSuffix("myopenhab.org") == nil, alwaysSendBasicAuth, !username.isEmpty, !password.isEmpty {
            request.headerFields[.authorization] = basicAuthHeader()
        }
        let (response, body) = try await next(request, body, baseURL)
        return (response, body)
    }
}
