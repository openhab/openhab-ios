// Copyright (c) 2010-2026 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Foundation
import os

@MainActor
public func onReceiveSessionTaskChallenge(with challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
    Logger.sessionChallenge.info("onReceiveSessionTaskChallenge host: \(String(describing: challenge.protectionSpace.host))")
    var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
    var credential: URLCredential?

    if challenge.previousFailureCount > 0 {
        return (.cancelAuthenticationChallenge, credential)
    } else if challenge.protectionSpace.authenticationMethod.isAny(of: NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodDefault) {
        let networkTracker = NetworkTracker.shared
        let activeConnection = await networkTracker.activeConnection
        guard let configuration = activeConnection?.configuration else { return (.cancelAuthenticationChallenge, credential) }
        if challenge.protectionSpace.host == URL(string: configuration.url)?.host || challenge.protectionSpace.host == "home.myopenhab.org" {
            credential = URLCredential(user: configuration.username, password: configuration.password, persistence: .forSession)
            disposition = .useCredential
            Logger.sessionChallenge.info(".useCredential")
        } else {
            Logger.sessionChallenge.error("No match \(challenge.protectionSpace.host) <> \(configuration.url)")
        }
    }
    return (disposition, credential)
}

@MainActor
public func onReceiveSessionChallenge(with challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
    Logger.sessionChallenge.warning("onReceiveSessionChallenge is not implemented fully (see TODOs)")
    Logger.sessionChallenge.info("onReceiveSessionChallenge host: \(String(describing: challenge.protectionSpace.host))")
    var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling

    switch challenge.protectionSpace.authenticationMethod {
    case NSURLAuthenticationMethodServerTrust:
        // Check if the active connection has ignoreSSL enabled
        if let activeConnection = await NetworkTracker.shared.activeConnection,
           activeConnection.configuration.ignoreSSL,
           let serverTrust = challenge.protectionSpace.serverTrust {
            Logger.sessionChallenge.info("Ignoring SSL certificate validation (ignoreSSL enabled)")
            return (.useCredential, URLCredential(trust: serverTrust))
        }
        return await CertificateManagers.serverCertificateManager.evaluateTrust(with: challenge)
    case NSURLAuthenticationMethodClientCertificate:
        return CertificateManagers.clientCertificateManager.evaluateTrust(with: challenge)
    // attemptCredentialAuthentication
    default:
        if challenge.previousFailureCount > 0 {
            disposition = .cancelAuthenticationChallenge
        } else {
            // TODO: in the last version, the httpClient had never been set and always remained nil. Figure out if and how this worked and if it is still needed
            // credential = await NetworkTracker.shared.httpClient?.session.configuration.urlCredentialStorage?.defaultCredential(for: challenge.protectionSpace)
            // if credential != nil {
            //    disposition = .useCredential
            // }
        }
        return (disposition, nil)
    }
}

final class SessionChallengeHandler {
    private let username: String
    private let password: String
    private let localUrl: URL?
    private let remoteUrl: URL?

    private let clientCertEvaluator: ((URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?))?
    private let serverTrustEvaluator: ((URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?))?

    init(username: String,
         password: String,
         localUrl: URL?,
         remoteUrl: URL?,
         serverTrustEvaluator: ((URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?))? = nil,
         clientCertEvaluator: ((URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?))? = nil) {
        self.username = username
        self.password = password
        self.localUrl = localUrl
        self.remoteUrl = remoteUrl
        self.serverTrustEvaluator = serverTrustEvaluator
        self.clientCertEvaluator = clientCertEvaluator
    }

    func handleSessionTaskChallenge(_ challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        Logger.sessionChallengeHandler.debug("SessionTaskChallenge host: \(challenge.protectionSpace.host, privacy: .public)")

        if challenge.previousFailureCount > 0 {
            return (.cancelAuthenticationChallenge, nil)
        }

        let authMethod = challenge.protectionSpace.authenticationMethod
        if authMethod == NSURLAuthenticationMethodHTTPBasic || authMethod == NSURLAuthenticationMethodDefault {
            if isTrustedHost(challenge.protectionSpace.host) {
                let credential = URLCredential(user: username, password: password, persistence: .forSession)
                Logger.sessionChallengeHandler.debug("Using HTTP BasicAuth for host: \(challenge.protectionSpace.host, privacy: .public)")
                return (.useCredential, credential)
            }
        }

        return (.performDefaultHandling, nil)
    }

    func handleSessionChallenge(_ challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        Logger.sessionChallengeHandler.debug("SessionChallenge host: \(challenge.protectionSpace.host, privacy: .public)")

        if challenge.previousFailureCount > 0 {
            return (.cancelAuthenticationChallenge, nil)
        }

        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodServerTrust:
            if let serverTrustEvaluator {
                return serverTrustEvaluator(challenge)
            }
        case NSURLAuthenticationMethodClientCertificate:
            if let clientCertEvaluator {
                return clientCertEvaluator(challenge)
            }
        default:
            // Try using stored credential if available
            if let credential = URLCredentialStorage.shared.defaultCredential(for: challenge.protectionSpace) {
                return (.useCredential, credential)
            }
        }

        return (.performDefaultHandling, nil)
    }

    private func isTrustedHost(_ host: String) -> Bool {
        host == localUrl?.host || host == remoteUrl?.host || host == "home.myopenhab.org"
    }
}
