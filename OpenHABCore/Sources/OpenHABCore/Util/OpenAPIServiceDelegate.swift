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

import Foundation
import os

// MARK: - URLSessionDelegate for Client Certificates and Basic Auth

final class OpenAPIServiceDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    private let username: String
    private let password: String
    private let authTracker = AuthAttemptTracker() // ✅ Use an actor instead of a dictionary

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await urlSessionInternal(session, task: nil, didReceive: challenge)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await urlSessionInternal(session, task: task, didReceive: challenge)
    }

    private func urlSessionInternal(_ session: URLSession, task: URLSessionTask?, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        os_log("URLAuthenticationChallenge: %{public}@", log: .networking, type: .info, challenge.protectionSpace.authenticationMethod)
        let authenticationMethod = challenge.protectionSpace.authenticationMethod
        switch authenticationMethod {
        case NSURLAuthenticationMethodServerTrust:
            let result = await handleServerTrust(challenge: challenge)
            await authTracker.resetAttempt(for: task) // ✅ Reset on success
            return result
        case NSURLAuthenticationMethodDefault, NSURLAuthenticationMethodHTTPBasic:
            if let task {
                let attemptCount = await authTracker.incrementAttempt(for: task) // ✅ Call actor asynchronously
                if attemptCount > 1 {
                    await authTracker.resetAttempt(for: task) // ✅ Reset if we cancel authentication
                    return (.cancelAuthenticationChallenge, nil)
                } else {
                    let result = await handleBasicAuth(challenge: challenge)
                    await authTracker.resetAttempt(for: task) // ✅ Reset on success
                    return result
                }
            } else {
                return await handleBasicAuth(challenge: challenge)
            }
        case NSURLAuthenticationMethodClientCertificate:
            let result = await handleClientCertificateAuth(challenge: challenge)
            await authTracker.resetAttempt(for: task) // ✅ Reset on success
            return result
        default:
            return (.performDefaultHandling, nil)
        }
    }

    private func handleServerTrust(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }
        let credential = URLCredential(trust: serverTrust)
        return (.useCredential, credential)
    }

    private func handleBasicAuth(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let credential = URLCredential(user: username, password: password, persistence: .forSession)
        return (.useCredential, credential)
    }

    private func handleClientCertificateAuth(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let certificateManager = ClientCertificateManager()
        let (disposition, credential) = certificateManager.evaluateTrust(with: challenge)
        return (disposition, credential)
    }
}
