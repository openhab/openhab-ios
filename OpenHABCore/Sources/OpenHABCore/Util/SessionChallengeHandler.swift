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
        let proxyHost = activeConnection?.proxyURL?.host
        if challenge.protectionSpace.host == URL(string: configuration.url)?.host
            || challenge.protectionSpace.host == proxyHost {
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
