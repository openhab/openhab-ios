//
//  NetworkConnection.swift
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

    var clientCertificateManager: ClientCertificateManager = ClientCertificateManager()
    var serverCertificateManager: ServerCertificateManager!

    var manager: Alamofire.SessionManager!
    static var shared: NetworkConnection!

    //let UIImageView.af_sharedImageDownloader = ImageDownloader(sessionManager: manager)

    class func initialize(ignoreSSL: Bool) {
        shared = NetworkConnection(ignoreSSL: ignoreSSL)
    }

    init(ignoreSSL: Bool) {
        serverCertificateManager = ServerCertificateManager(ignoreCertificates: ignoreSSL)

        serverCertificateManager.initializeCertificatesStore()

        manager = Alamofire.SessionManager(configuration: URLSessionConfiguration.default, delegate: SessionDelegate())
        manager.startRequestsImmediately = false

        manager.delegate.sessionDidReceiveChallenge = { [weak self] session, challenge in
            guard let self = self else { return (.performDefaultHandling, nil) }

            var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
            var credential: URLCredential?

            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                (disposition, credential) = self.serverCertificateManager.evaluateTrust(challenge: challenge)
            } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
                (disposition, credential) = self.clientCertificateManager.evaluateTrust(challenge: challenge)
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

        manager.delegate.taskDidReceiveChallenge = { session, task, challenge in
            var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
            var credential: URLCredential?

            if challenge.previousFailureCount > 0 {
                disposition = .cancelAuthenticationChallenge
            } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic {
                let prefs = UserDefaults.standard
                let remoteURL = URL(string: prefs.string(forKey: "remoteUrl") ?? "")
                let localURL = URL(string: prefs.string(forKey: "localURL") ?? "")

                if challenge.protectionSpace.host == remoteURL?.host || challenge.protectionSpace.host == localURL?.host {
                    let openHABUsername = prefs.string(forKey: "username") ?? ""
                    let openHABPassword = prefs.string(forKey: "password") ?? ""
                    credential = URLCredential(user: openHABUsername, password: openHABPassword, persistence: .forSession)
                    disposition = .useCredential
                    os_log("HTTP BasicAuth host:'%{PUBLIC}@'", log: .default, type: .error, challenge.protectionSpace.host)
                }
            }
            return (disposition, credential)
        }
    }

    func assignDelegates(serverDelegate: ServerCertificateManagerDelegate?, clientDelegate: ClientCertificateManagerDelegate) {
        serverCertificateManager.delegate = serverDelegate
        clientCertificateManager.delegate = clientDelegate
    }
}
