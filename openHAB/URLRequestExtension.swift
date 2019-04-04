//
//  URLRequestExtension.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 04.04.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation

extension URLRequest {
    static func webUIRequest(url: URL) -> URLRequest? {
        var request = URLRequest(url: url)
        let prefs = UserDefaults.standard
        let openHABUsername = prefs.string(forKey: "username")
        let openHABPassword = prefs.string(forKey: "password")
        let authStr = "\(openHABUsername ?? ""):\(openHABPassword ?? "")"

        guard let loginData = authStr.data(using: String.Encoding.utf8) else {
            return nil
        }
        let base64LoginString = loginData.base64EncodedString()

        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")

        return request
    }
}
