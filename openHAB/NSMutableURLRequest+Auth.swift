//  Converted to Swift 4 by Swiftify v4.2.20229 - https://objectivec2swift.com/
//
//  Inspired by Victor Belov on 10/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Created by Tim Müller-Seydlitz on 09.06.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation

extension URLRequest {
    mutating func setAuthCredentials(_ username: String?, _ password: String?) {
        let loginString = "\(username ?? ""):\(password ?? "")"
        let loginData = loginString.data(using: .utf8)
        let authValue = "Basic \(loginData?.base64EncodedString() ?? "")"
        setValue(authValue, forHTTPHeaderField: "Authorization")
    }
}
