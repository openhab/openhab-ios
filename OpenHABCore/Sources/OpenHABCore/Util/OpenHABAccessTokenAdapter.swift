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
import Kingfisher

public final class OpenHABAccessTokenAdapter {
    let connectionConfiguration: ConnectionConfiguration?

    public init(connectionConfiguration: ConnectionConfiguration) {
        self.connectionConfiguration = connectionConfiguration
    }

    public func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        guard let connectionConfiguration else { return urlRequest }
        guard connectionConfiguration.alwaysSendBasicAuth || connectionConfiguration.isCloudConnection else {
            // The user did not choose for the credentials to be sent with every request.
            return urlRequest
        }

        let user = connectionConfiguration.username
        let password = connectionConfiguration.password
        guard !user.isEmpty, !password.isEmpty else {
            // In order to set the credentials on the `URLRequestt`, both username and password must be set up.
            return urlRequest
        }

        var urlRequest = urlRequest

        // We are handling URLRequests here, so we need to set the header fields
        // to the request object with String and cannot use the type safe way of HTTPRequest
        // like request.headerFields[.authorization] = basicAuthHeader()
        // TODO: revert this!!
        urlRequest.setValue(basicAuthHeader(username: user, password: password), forHTTPHeaderField: "Authorization")
        return urlRequest
    }
}

extension OpenHABAccessTokenAdapter: ImageDownloadRequestModifier {
    public func modified(for request: URLRequest) -> URLRequest? {
        do {
            return try adapt(request)
        } catch {
            return request
        }
    }
}
