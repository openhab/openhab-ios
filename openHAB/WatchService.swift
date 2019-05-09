//
//  WatchService.swift
//  nightguard
//
//  Created by Dirk Hermanns on 01.06.18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation
import WatchConnectivity

class WatchService {
    
    static let singleton = WatchService()
    
    private var lastSentNightscoutDataTime: NSNumber?
    private var lastWatchUpdateTime: Date?
    private var lastWatchComplicationUpdateTime: Date?
    
    func sendToWatch(_ localUrl : String, remoteUrl : String,
                     username : String, password: String, sitemapName : String) {
        
        let applicationDict : [String : Any] =
            ["localUrl" : localUrl,
             "remoteUrl" : remoteUrl,
             "username" : username,
             "password" : password,
             "sitemapName" : sitemapName]
        
        sendOrTransmitToWatch(applicationDict)
    }
    
    private func sendOrTransmitToWatch(_ message: [String : Any]) {
        
        // send message if watch is reachable
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: { data in
                print("Received data: \(data)")
            }, errorHandler: { error in
                print(error)
                
                // transmit message on failure
                try? WCSession.default.updateApplicationContext(message)
            })
        } else {
            
            // otherwise, transmit application context
            try? WCSession.default.updateApplicationContext(message)
        }
    }
}
