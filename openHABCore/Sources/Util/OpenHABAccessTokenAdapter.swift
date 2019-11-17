// Copyright (c) 2010-2019 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Alamofire
import Foundation
import Kingfisher

public class OpenHABAccessTokenAdapter: RequestAdapter {
    var appData: DataObject

    public init(appData data: DataObject) {
        appData = data
    }

    public func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        var urlRequest = urlRequest

        if let authorizationHeader = Request.authorizationHeader(user: appData.openHABUsername, password: appData.openHABPassword) {
            urlRequest.setValue(authorizationHeader.value, forHTTPHeaderField: authorizationHeader.key)
        }

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
