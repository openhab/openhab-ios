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
let onReceiveSessionTaskChallenge = { (session: URLSession, task: URLSessionTask, challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) in

    var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
    var credential: URLCredential?

    if challenge.previousFailureCount > 0 {
        return (.cancelAuthenticationChallenge, credential)
    } else if challenge.protectionSpace.authenticationMethod.isAny(of: NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodDefault) {
        if challenge.protectionSpace.host == NetworkConnection.shared.rootUrl?.host {
            credential = URLCredential(user: Preferences.username, password: Preferences.password, persistence: .forSession)
            disposition = .useCredential
            os_log("HTTP BasicAuth host:'%{PUBLIC}@'", log: .default, type: .error, challenge.protectionSpace.host)
        }
    }
    return (disposition, credential)
}

let onReceiveSessionChallenge = { (session: URLSession, challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) in

    var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
    var credential: URLCredential?

    switch challenge.protectionSpace.authenticationMethod {
    case NSURLAuthenticationMethodServerTrust:
        return NetworkConnection.shared.serverCertificateManager.evaluateTrust(challenge: challenge)
    case NSURLAuthenticationMethodClientCertificate:
        return NetworkConnection.shared.clientCertificateManager.evaluateTrust(challenge: challenge)
    default:
        if challenge.previousFailureCount > 0 {
            disposition = .cancelAuthenticationChallenge
        } else {
            credential = NetworkConnection.shared.manager.session.configuration.urlCredentialStorage?.defaultCredential(for: challenge.protectionSpace)
            if credential != nil {
                disposition = .useCredential
            }
        }
        return (disposition, credential)
    }
}

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
        manager.delegate.sessionDidReceiveChallenge = onReceiveSessionChallenge
        manager.delegate.taskDidReceiveChallenge = onReceiveSessionTaskChallenge
        manager.adapter = OpenHABAccessTokenAdapter()
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
