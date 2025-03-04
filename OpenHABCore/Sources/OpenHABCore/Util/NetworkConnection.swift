// Copyright (c) 2010-2025 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Alamofire
import Foundation
import os.log

public func onReceiveSessionTaskChallenge(with challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
    os_log("onReceiveSessionTaskChallenge host:'%{PUBLIC}@'", log: .default, type: .error, challenge.protectionSpace.host)
    var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
    var credential: URLCredential?

    if challenge.previousFailureCount > 0 {
        return (.cancelAuthenticationChallenge, credential)
    } else if challenge.protectionSpace.authenticationMethod.isAny(of: NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodDefault) {
        let localUrl = URL(string: Preferences.localUrl)
        let remoteUrl = URL(string: Preferences.remoteUrl)
        if challenge.protectionSpace.host == localUrl?.host || challenge.protectionSpace.host == remoteUrl?.host || challenge.protectionSpace.host == "home.myopenhab.org" {
            credential = URLCredential(user: Preferences.username, password: Preferences.password, persistence: .forSession)
            disposition = .useCredential
            os_log("HTTP BasicAuth host:'%{PUBLIC}@'", log: .default, type: .error, challenge.protectionSpace.host)
        }
    }
    return (disposition, credential)
}

public func onReceiveSessionChallenge(with challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
    os_log("onReceiveSessionChallenge host:'%{PUBLIC}@'", log: .default, type: .error, challenge.protectionSpace.host)
    var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
    var credential: URLCredential?

    switch challenge.protectionSpace.authenticationMethod {
    case NSURLAuthenticationMethodServerTrust:
        // TODO:
        return (NetworkTracker.shared.serverCertificateManager?.evaluateTrust(with: challenge))!
    case NSURLAuthenticationMethodClientCertificate:
        return NetworkTracker.shared.clientCertificateManager.evaluateTrust(with: challenge)
    // attemptCredentialAuthentication
    default:
        if challenge.previousFailureCount > 0 {
            disposition = .cancelAuthenticationChallenge
        } else {
            credential = NetworkTracker.shared.httpClient?.session.configuration.urlCredentialStorage?.defaultCredential(for: challenge.protectionSpace)
            if credential != nil {
                disposition = .useCredential
            }
        }
        return (disposition, credential)
    }
}

public protocol CommItem {
    var link: String { get set }
}
