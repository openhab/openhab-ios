//  Converted to Swift 4 by Swiftify v4.2.20229 - https://objectivec2swift.com/
//
//  NSURLRequest+Auth.h
//  HelloRestKit
//
//  Created by Victor Belov on 10/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

import Foundation

extension URLRequest {
    mutating func setAuthCredentials(_ username: String?, _ password: String?) {
        let authStr = "\(username ?? ""):\(password ?? "")"
        let authData: Data? = authStr.data(using: .ascii)
        let authValue = "Basic \(authData?.base64EncodedString(options: []) ?? "")"
        setValue(authValue, forHTTPHeaderField: "Authorization")
    }
}
