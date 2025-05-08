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

public final class HTTPClientDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    private let connectionConfiguration: ConnectionConfiguration
    private var evaluateContinuation: CheckedContinuation<CertificateEvaluateResult, Never>?

    private let logger = Logger(subsystem: "org.openhab.core", category: "HTTPClientDelegate")

    let store = CertificateStore()

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
        logger.debug("URLAuthenticationChallenge: \(authenticationMethod)")

        if challenge.previousFailureCount > 0 {
            return (.cancelAuthenticationChallenge, nil)
        } else {
            switch authenticationMethod {
            case NSURLAuthenticationMethodServerTrust:
                let result = await handleServerTrust(challenge: challenge)
                return result
            case NSURLAuthenticationMethodDefault, NSURLAuthenticationMethodHTTPBasic:
                let result = await handleBasicAuth(challenge: challenge)
                return result
            case NSURLAuthenticationMethodClientCertificate:
                let result = await handleClientCertificateAuth(challenge: challenge)
                return result
            default:
                return (.performDefaultHandling, nil)
            }
        }
    }

    private func handleServerTrust(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let domain = challenge.protectionSpace.host
        logger.info("Handling server trust for domain: \(domain)")

        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            logger.error("No server trust object available")
            return (.cancelAuthenticationChallenge, nil)
        }

        var result: SecTrustResultType = .invalid
        var error: CFError?
        _ = SecTrustEvaluateWithError(serverTrust, &error)
        SecTrustGetTrustResult(serverTrust, &result)
        logger.info("Trust evaluation result: \(result.rawValue), error: \(String(describing: error))")

        if result.isAny(of: .unspecified, .proceed) || connectionConfiguration.ignoreSSL {
            logger.info("Certificate is trusted or SSL verification ignored")
            return (.useCredential, URLCredential(trust: serverTrust))
        }

        guard let certificate = getLeafCertificate(trust: serverTrust) else {
            logger.error("Could not get leaf certificate")
            return (.cancelAuthenticationChallenge, nil)
        }

        let certificateSummary = SecCertificateCopySubjectSummary(certificate)
        let certificateData = SecCertificateCopyData(certificate)

        // If we have a certificate for this domain
        if let previousCertificateData = await store.certificateData(forDomain: domain) {
            if CFEqual(previousCertificateData as CFData, certificateData) {
                logger.info("Using previously trusted certificate for domain: \(domain)")
                return (.useCredential, URLCredential(trust: serverTrust))
            } else {
                logger.warning("Certificate mismatch detected for domain: \(domain)")
                // Certificate mismatch - possible MitM attack
                NotificationCenter.default.post(
                    name: .evaluateCertificateMismatch,
                    object: self,
                    userInfo: ["summary": certificateSummary as Any, "domain": domain]
                )
                let evaluateResult = await waitForEvaluation()
                logger.info("User decision for certificate mismatch: \(String(describing: evaluateResult))")

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
        }

        // New certificate
        logger.info("New untrusted certificate for domain: \(domain)")
        NotificationCenter.default.post(
            name: .evaluateServerTrust,
            object: self,
            userInfo: ["summary": certificateSummary as Any, "domain": domain]
        )
        let evaluateResult = await waitForEvaluation()
        logger.info("User decision for new certificate: \(String(describing: evaluateResult))")

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

    private func handleBasicAuth(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let credential = URLCredential(user: connectionConfiguration.username, password: connectionConfiguration.password, persistence: .forSession)
        return (.useCredential, credential)
    }

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
            evaluateContinuation = continuation
        }
    }

    public func completeEvaluation(_ result: CertificateEvaluateResult) {
        logger.info("Completing evaluation with result: \(String(describing: result))")
        evaluateContinuation?.resume(returning: result)
        evaluateContinuation = nil
    }
}
