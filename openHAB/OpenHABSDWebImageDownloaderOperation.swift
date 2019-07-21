//
//  OpenHABSDWebImageDownloaderOperation.swift
//  openHAB
//
//  Created by David O'Neill on 06/03/19.
//  Copyright (c) 2019 David O'Neill. All rights reserved.
//

import SDWebImage

class OpenHABSDWebImageDownloaderOperation: SDWebImageDownloaderOperation {
    override func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            if let dns = challenge.protectionSpace.distinguishedNames,
                let identity = OpenHABHTTPRequestOperation.clientCertificateManager.evaluateTrust(distinguishedNames: dns) {
                let credential = URLCredential.init(identity: identity, certificates: nil, persistence: URLCredential.Persistence.forSession)
                let disposition = URLSession.AuthChallengeDisposition.useCredential
                completionHandler(disposition, credential)
                return
            }
            let disposition = URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge
            completionHandler(disposition, nil)
            return
        }
        // Not a client certificate request to run the default handler
        super.urlSession(session, task: task, didReceive: challenge, completionHandler: completionHandler)
    }
}
