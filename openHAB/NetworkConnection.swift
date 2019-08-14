//
//  BetworkConnection.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 10/08/19.
//  Copyright (c) 2019 David O'Neill. All rights reserved.

import Alamofire
import os.log

// https://medium.com/@AladinWay/write-a-networking-layer-in-swift-4-using-alamofire-5-and-codable-part-2-perform-request-and-b5c7ee2e012d
// Transition from AFNetworking to Alamofire 5.0
// SessionManager --> Session
// serverTrustPolicyManager --> serverTrustManager
// ServerTrustPolicyManager --> ServerTrustManager

class NetworkConnection {

    static var clientCertificateManager: ClientCertificateManager = ClientCertificateManager()

    var manager: Alamofire.SessionManager!
    static let shared = NetworkConnection()

    init() {

        manager = Alamofire.SessionManager(configuration: URLSessionConfiguration.default, delegate: SessionDelegate(), serverTrustPolicyManager: AlamofireRememberingSecurityPolicy(ignoreCertificates: true) )

        manager.delegate.sessionDidReceiveChallenge = { session, challenge in
            var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
            var credential: URLCredential?

            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                disposition = URLSession.AuthChallengeDisposition.useCredential
                credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
                (disposition, credential) = self.evaluateClientTrust(challenge: challenge)
            } else {
                if challenge.previousFailureCount > 0 {
                    disposition = .cancelAuthenticationChallenge
                } else {
                    credential = self.manager.session.configuration.urlCredentialStorage?.defaultCredential(for: challenge.protectionSpace)

                    if credential != nil {
                        disposition = .useCredential
                    }
                }
            }

            return (disposition, credential)
        }
    }

    func evaluateClientTrust(challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let dns = challenge.protectionSpace.distinguishedNames
        if let dns = dns {
            let identity = NetworkConnection.clientCertificateManager.evaluateTrust(distinguishedNames: dns)
            if let identity = identity {
                let credential = URLCredential.init(identity: identity, certificates: nil, persistence: URLCredential.Persistence.forSession)
                return (.useCredential, credential)
            }
        }
        return (.cancelAuthenticationChallenge, nil)
    }
}
