//  Converted to Swift 4 by Swiftify v4.2.28153 - https://objectivec2swift.com/
//
//  Reachability+URL.swift
//  openHAB
//
//  Created by Victor Belov on 13/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

extension Reachability {
    convenience init(urlString: String?) {
        let url = URL(string: urlString ?? "")
        self.init(url: url)
    }

    convenience init(url: URL?) {
        self.withHostName(url?.host)
    }

    func currentlyReachable() -> Bool {
        let netStatus: NetworkStatus = currentReachabilityStatus()
        if netStatus == ReachableViaWiFi || netStatus == ReachableViaWWAN {
            return true
        }
        return false
    }
}