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

    static var shared: NetworkConnection!

    var clientCertificateManager = ClientCertificateManager()
    var serverCertificateManager: ServerCertificateManager!
    var manager: Alamofire.SessionManager!
    var rootUrl: URL?

    init(ignoreSSL: Bool) {
        serverCertificateManager = ServerCertificateManager(ignoreCertificates: ignoreSSL)

        serverCertificateManager.initializeCertificatesStore()

        manager = Alamofire.SessionManager(configuration: URLSessionConfiguration.default, delegate: SessionDelegate())
        manager.startRequestsImmediately = false

        manager.delegate.sessionDidReceiveChallenge = { [weak self] session, challenge in
            guard let self = self else { return (.performDefaultHandling, nil) }

            var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
            var credential: URLCredential?

            switch challenge.protectionSpace.authenticationMethod {
            case NSURLAuthenticationMethodServerTrust:
                (disposition, credential) = self.serverCertificateManager.evaluateTrust(challenge: challenge)
            case NSURLAuthenticationMethodClientCertificate:
                (disposition, credential) = self.clientCertificateManager.evaluateTrust(challenge: challenge)
            default:
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
            } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic ||
                challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodDefault {
                if challenge.protectionSpace.host == self.rootUrl?.host {
                    let openHABUsername = Preferences.username
                    let openHABPassword = Preferences.password
                    credential = URLCredential(user: openHABUsername, password: openHABPassword, persistence: .forSession)
                    disposition = .useCredential
                    os_log("HTTP BasicAuth host:'%{PUBLIC}@'", log: .default, type: .error, challenge.protectionSpace.host)
                }
            }
            return (disposition, credential)
        }
    }

    class func initialize(ignoreSSL: Bool) {
        shared = NetworkConnection(ignoreSSL: ignoreSSL)
    }

    func assignDelegates(serverDelegate: ServerCertificateManagerDelegate?, clientDelegate: ClientCertificateManagerDelegate) {
        serverCertificateManager.delegate = serverDelegate
        clientCertificateManager.delegate = clientDelegate
    }

    func setRootUrl(_ url: String?) {
        self.rootUrl = URL(string: url ?? "")
    }
}
