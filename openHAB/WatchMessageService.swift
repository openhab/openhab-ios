//
//  WatchMessageService.swift
//  openhabwatch
//
//  Created by Dirk Hermanns on 31.05.18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation
import WatchConnectivity

// This class receives Watch Request for the configuration data like localUrl.
// The functionality is activated in the AppDelegate.
class WatchMessageService : NSObject, WCSessionDelegate {
    
    static let singleton = WatchMessageService()
    
    // This method gets called when the watch requests the localUrl
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        
        //TODO Use RemoteUrl, TOO
        if message["requestLocalUrl"] != nil {
            let prefs = UserDefaults.standard
            replyHandler(["baseUri": prefs.string(forKey: "localUrl") ?? ""])
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("Received message: \(message)")
    }
    
    @available(iOS 9.3, *)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
    }
}
