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

actor CertificateEvaluationState {
    private var continuation: CheckedContinuation<CertificateEvaluateResult, Never>?

    func store(_ continuation: CheckedContinuation<CertificateEvaluateResult, Never>) {
        self.continuation = continuation
    }

    func complete(_ result: CertificateEvaluateResult) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}

// MARK: - URLSessionDelegate for Client Certificates and Basic Auth

public final class HTTPClientDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    private let connectionConfiguration: ConnectionConfiguration
    private let evaluationState = CertificateEvaluationState()

    let store = CertificateStore.shared

    init(with connectionConfiguration: ConnectionConfiguration) {
        self.connectionConfiguration = connectionConfiguration
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await urlSessionInternal(session, task: nil, didReceive: challenge)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await urlSessionInternal(session, task: task, didReceive: challenge)
    }

    private func urlSessionInternal(_ session: URLSession, task: URLSessionTask?, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let authenticationMethod = challenge.protectionSpace.authenticationMethod
        Logger.httpClientDelegate.debug("URLAuthenticationChallenge: \(authenticationMethod)")

        if challenge.previousFailureCount > 0 {
            return (.cancelAuthenticationChallenge, nil)
        }
        switch authenticationMethod {
        case NSURLAuthenticationMethodServerTrust:
            return await handleServerTrust(challenge: challenge)
        case NSURLAuthenticationMethodDefault, NSURLAuthenticationMethodHTTPBasic:
            return await handleBasicAuth(challenge: challenge)
        case NSURLAuthenticationMethodClientCertificate:
            return await handleClientCertificateAuth(challenge: challenge)
        default:
            return (.performDefaultHandling, nil)
        }
    }

    private func handleServerTrust(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let domain = challenge.protectionSpace.host
        Logger.httpClientDelegate.info("Handling server trust for domain: \(domain)")

        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            Logger.httpClientDelegate.error("No server trust object available")
            return (.cancelAuthenticationChallenge, nil)
        }

        var result: SecTrustResultType = .invalid
        var error: CFError?
        _ = SecTrustEvaluateWithError(serverTrust, &error)
        SecTrustGetTrustResult(serverTrust, &result)
        Logger.httpClientDelegate.info("Trust evaluation result: \(result), error: \(String(describing: error))")

        if result.isAny(of: .unspecified, .proceed) || connectionConfiguration.ignoreSSL {
            Logger.httpClientDelegate.info("Certificate is trusted or SSL verification ignored")
            return (.useCredential, URLCredential(trust: serverTrust))
        }

        guard let certificate = getLeafCertificate(trust: serverTrust) else {
            Logger.httpClientDelegate.error("Could not get leaf certificate")
            return (.cancelAuthenticationChallenge, nil)
        }

        let certificateSummary = SecCertificateCopySubjectSummary(certificate)
        let certificateData = SecCertificateCopyData(certificate)

        // If we have a certificate for this domain
        if let previousCertificateData = await store.certificateData(forDomain: domain) {
            if CFEqual(previousCertificateData as CFData, certificateData) {
                Logger.httpClientDelegate.info("Using previously trusted certificate for domain: \(domain)")
                return (.useCredential, URLCredential(trust: serverTrust))
            }
            Logger.httpClientDelegate.warning("Certificate mismatch detected for domain: \(domain)")
            // Certificate mismatch - possible MitM attack
            NotificationCenter.default.post(
                name: .evaluateCertificateMismatch,
                object: self,
                userInfo: ["summary": certificateSummary as Any, "domain": domain]
            )
            let evaluateResult = await waitForEvaluation()
            Logger.httpClientDelegate.info("User decision for certificate mismatch: \(String(describing: evaluateResult))")

            switch evaluateResult {
            case .deny:
                return (.cancelAuthenticationChallenge, nil)
            case .permitOnce:
                return (.useCredential, URLCredential(trust: serverTrust))
            case .permitAlways:
                await store.storeCertificateData(certificateData as Data, forDomain: domain)
                NotificationCenter.default.post(name: .acceptedServerCertificatesChanged, object: self)
                return (.useCredential, URLCredential(trust: serverTrust))
            case .undecided:
                return (.cancelAuthenticationChallenge, nil)
            }
        }

        // New certificate
        Logger.httpClientDelegate.info("New untrusted certificate for domain: \(domain)")
        NotificationCenter.default.post(
            name: .evaluateServerTrust,
            object: self,
            userInfo: ["summary": certificateSummary as Any, "domain": domain]
        )
        let evaluateResult = await waitForEvaluation()
        Logger.httpClientDelegate.info("User decision for new certificate: \(String(describing: evaluateResult))")

        switch evaluateResult {
        case .deny:
            return (.cancelAuthenticationChallenge, nil)
        case .permitOnce:
            return (.useCredential, URLCredential(trust: serverTrust))
        case .permitAlways:
            await store.storeCertificateData(certificateData as Data, forDomain: domain)
            NotificationCenter.default.post(name: .acceptedServerCertificatesChanged, object: self)
            return (.useCredential, URLCredential(trust: serverTrust))
        case .undecided:
            return (.cancelAuthenticationChallenge, nil)
        }
    }

    // swiftlint:disable:next async_without_await
    private func handleBasicAuth(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let credential = URLCredential(user: connectionConfiguration.username, password: connectionConfiguration.password, persistence: .forSession)
        return (.useCredential, credential)
    }

    // swiftlint:disable:next async_without_await
    private func handleClientCertificateAuth(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let certificateManager = ClientCertificateManager()
        let (disposition, credential) = certificateManager.evaluateTrust(with: challenge)
        return (disposition, credential)
    }

    // MARK: - SSL Certificate Handling

    private func getLeafCertificate(trust: SecTrust?) -> SecCertificate? {
        if let trust, SecTrustGetCertificateCount(trust) > 0,
           let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate] {
            return certificates[0]
        }
        return nil
    }

    public func waitForEvaluation() async -> CertificateEvaluateResult {
        await withCheckedContinuation { continuation in
            Task {
                await evaluationState.store(continuation)
            }
        }
    }

    public func completeEvaluation(_ result: CertificateEvaluateResult) {
        Task {
            await evaluationState.complete(result)
        }
    }
}

extension SecTrustResultType: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalid:
            return "invalid"
        case .proceed:
            return "proceed"
        case .deny:
            return "deny"
        case .unspecified:
            return "unspecified"
        case .recoverableTrustFailure:
            return "recoverableTrustFailure"
        case .fatalTrustFailure:
            return "fatalTrustFailure"
        case .otherError:
            return "otherError"
        case .confirm:
            return "confirm"
        @unknown default:
            return "unknown(\(rawValue))"
        }
    }
}
