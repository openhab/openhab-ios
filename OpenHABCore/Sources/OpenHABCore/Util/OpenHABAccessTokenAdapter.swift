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
import Kingfisher

public class OpenHABAccessTokenAdapter {
    var appData: DataObject

    public init(appData data: DataObject) {
        appData = data
    }

    public func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        guard appData.openHABAlwaysSendCreds || urlRequest.url?.host?.hasSuffix("myopenhab.org") == true else {
            // The user did not choose for the credentials to be sent with every request.
            return urlRequest
        }

        let user = appData.openHABUsername
        let password = appData.openHABPassword
        guard !user.isEmpty, !password.isEmpty else {
            // In order to set the credentials on the `URLRequestt`, both username and password must be set up.
            return urlRequest
        }

        var urlRequest = urlRequest

        func basicAuthHeader() -> String {
            let authString = "\(user):\(password)"
            let authData = authString.data(using: .utf8)!
            return "Basic \(authData.base64EncodedString())"
        }
        // We are handling URLRequests here, so we need to set the header fields
        // to the request object with String and cannot use the type safe way of HTTPRequest
        // like request.headerFields[.authorization] = basicAuthHeader()
        // TODO: revert this!!
        urlRequest.setValue(basicAuthHeader(), forHTTPHeaderField: "Authorization")
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
