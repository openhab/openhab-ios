// Copyright (c) 2010-2024 Contributors to the openHAB project
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

// Alamofire 5 does not provide client certificate handling via a taskDidReceiveChallenge closure:
// The alternative method is explained by jshier in https://github.com/Alamofire/Alamofire/issues/2886#issuecomment-517951747

class OpenHABSessionDelegate: SessionDelegate {
    // swiftlint:disable:next large_tuple
    typealias ChallengeEvaluation = (disposition: URLSession.AuthChallengeDisposition, credential: URLCredential?, error: AFError?)

    var eventMonitor: EventMonitor?

    override func urlSession(_ session: URLSession,
                             task: URLSessionTask,
                             didReceive challenge: URLAuthenticationChallenge,
                             completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        eventMonitor?.urlSession(session, task: task, didReceive: challenge)

        let evaluation: ChallengeEvaluation
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodHTTPBasic:
            evaluation = determineEvaluation(with: challenge.protectionSpace.host)
        case NSURLAuthenticationMethodHTTPDigest, NSURLAuthenticationMethodNTLM,
             NSURLAuthenticationMethodNegotiate:
            (evaluation.disposition, evaluation.credential) = NetworkConnection.shared.clientCertificateManager.evaluateTrust(with: challenge)
            evaluation.error = nil
        #if !(os(Linux) || os(Windows))
        case NSURLAuthenticationMethodServerTrust:
            (evaluation.disposition, evaluation.credential) = NetworkConnection.shared.serverCertificateManager.evaluateTrust(with: challenge)
            evaluation.error = nil
        case NSURLAuthenticationMethodClientCertificate:
            // evaluation = attemptCredentialAuthentication(for: challenge, belongingTo: task)
            (evaluation.disposition, evaluation.credential) = NetworkConnection.shared.clientCertificateManager.evaluateTrust(with: challenge)
            evaluation.error = nil
        #endif
        default:
            evaluation = determineEvaluation(with: challenge.protectionSpace.host)
        }

        completionHandler(evaluation.disposition, evaluation.credential)
    }

    private func determineEvaluation(with host: String) -> ChallengeEvaluation {
        let localUrl = URL(string: Preferences.localUrl)
        let remoteUrl = URL(string: Preferences.remoteUrl)
        if host == localUrl?.host || host == remoteUrl?.host {
            let credential = URLCredential(user: Preferences.username, password: Preferences.password, persistence: .forSession)
            return (.useCredential, credential, nil)
        } else {
            return (.performDefaultHandling, nil, nil)
        }
    }
}
