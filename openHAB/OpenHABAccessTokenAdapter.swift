//
//  AccessTokenAdaptor.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 12.09.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Alamofire
import Foundation
import Kingfisher

class OpenHABAccessTokenAdapter: RequestAdapter {
    var appData: OpenHABDataObject? {
        return AppDelegate.appDelegate.appData
    }

    func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        var urlRequest = urlRequest

        guard let user = appData?.openHABUsername, let password = appData?.openHABPassword else { return urlRequest }

        if let authorizationHeader = Request.authorizationHeader(user: user, password: password) {
            urlRequest.setValue(authorizationHeader.value, forHTTPHeaderField: authorizationHeader.key)
        }

        return urlRequest
    }
}

extension OpenHABAccessTokenAdapter: ImageDownloadRequestModifier {
    func modified(for request: URLRequest) -> URLRequest? {
        do {
            return try adapt(request)
        } catch {
            return request
        }
    }
}
