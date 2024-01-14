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
import SDWebImage

class OpenHABRequestModifier: SDWebImageDownloaderRequestModifier {
    var appData: ObservableOpenHABDataObject

    public init(appData data: ObservableOpenHABDataObject) {
        appData = data
        super.init()
    }

    override func modifiedRequest(with request: URLRequest) -> URLRequest? {
        guard appData.openHABAlwaysSendCreds || request.url?.host?.hasSuffix("myopenhab.org") == true else {
            // The user did not choose for the credentials to be sent with every request.
            return request
        }

        let user = appData.openHABUsername
        let password = appData.openHABPassword
        guard !user.isEmpty, !password.isEmpty else {
            // In order to set the credentials on the `URLRequestt`, both username and password must be set up.
            return request
        }

        var request = request
        request.headers.add(.authorization(username: user, password: password))
        return request
    }
}
