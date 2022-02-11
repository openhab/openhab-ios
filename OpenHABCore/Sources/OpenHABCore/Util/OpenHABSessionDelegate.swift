// Copyright (c) 2010-2022 Contributors to the openHAB project
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
    typealias ChallengeEvaluation = (disposition: URLSession.AuthChallengeDisposition, credential: URLCredential?, error: AFError?)

    var eventMonitor: EventMonitor?

    override func urlSession(_ session: URLSession,
                             task: URLSessionTask,
                             didReceive challenge: URLAuthenticationChallenge,
                             completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        eventMonitor?.urlSession(session, task: task, didReceive: challenge)

        let evaluation: ChallengeEvaluation
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest, NSURLAuthenticationMethodNTLM,
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
            evaluation = (.performDefaultHandling, nil, nil)
        }

        completionHandler(evaluation.disposition, evaluation.credential)
    }
}
