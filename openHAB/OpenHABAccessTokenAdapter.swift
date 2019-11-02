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
#if !os(watchOS)
import Kingfisher
#endif

class OpenHABAccessTokenAdapter: RequestAdapter {
    #if !os(watchOS)
    var appData: OpenHABDataObject? {
        return AppDelegate.appDelegate.appData
    }

    #else
    var appData: OpenHABDataObject? {
        return nil
        #warning("Must be reworked")
    }
    #endif

    #if !os(watchOS)
    func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        var urlRequest = urlRequest

        guard let user = appData?.openHABUsername, let password = appData?.openHABPassword else { return urlRequest }

        if let authorizationHeader = Request.authorizationHeader(user: user, password: password) {
            urlRequest.setValue(authorizationHeader.value, forHTTPHeaderField: authorizationHeader.key)
        }

        return urlRequest
    }

    #else
    func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        var urlRequest = urlRequest

        guard let user = appData?.openHABUsername, let password = appData?.openHABPassword else { return urlRequest }

        if let authorizationHeader = Request.authorizationHeader(user: user, password: password) {
            urlRequest.setValue(authorizationHeader.value, forHTTPHeaderField: authorizationHeader.key)
        }

        return urlRequest
    }
    #endif
}

#if !os(watchOS)
extension OpenHABAccessTokenAdapter: ImageDownloadRequestModifier {
    func modified(for request: URLRequest) -> URLRequest? {
        do {
            return try adapt(request)
        } catch {
            return request
        }
    }
}
#endif
