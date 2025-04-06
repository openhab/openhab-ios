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
    private let connectionConfiguration: ConnectionConfiguration
    private var trustedCertificates: [String: Data] = [:]
    private var evaluateContinuation: CheckedContinuation<CertificateEvaluateResult, Never>?

    private let logger = Logger(subsystem: "org.openhab.core", category: "OpenAPIServiceDelegate")

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
                let result = handleBasicAuth(challenge: challenge)
                return result
            case NSURLAuthenticationMethodClientCertificate:
                let result = handleClientCertificateAuth(challenge: challenge)
                return result
            default:
                return (.performDefaultHandling, nil)
            }
        }
    }

    private func handleServerTrust(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let domain = challenge.protectionSpace.host
        logger.debug("Handling server trust for domain: \(domain)")

        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            logger.error("No server trust object available")
            return (.cancelAuthenticationChallenge, nil)
        }

        var result: SecTrustResultType = .invalid
        var error: CFError?
        _ = SecTrustEvaluateWithError(serverTrust, &error)
        SecTrustGetTrustResult(serverTrust, &result)

        if result.isAny(of: .unspecified, .proceed) || connectionConfiguration.ignoreSSL {
            logger.debug("Certificate is trusted or SSL verification ignored")
            return (.useCredential, URLCredential(trust: serverTrust))
        }

        guard let certificate = getLeafCertificate(trust: serverTrust) else {
            logger.error("Could not get leaf certificate")
            return (.cancelAuthenticationChallenge, nil)
        }

        let certificateSummary = SecCertificateCopySubjectSummary(certificate)
        let certificateData = SecCertificateCopyData(certificate)

        // If we have a certificate for this domain
        if let previousCertificateData = self.certificateData(forDomain: domain) {
            if CFEqual(previousCertificateData, certificateData) {
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
                    storeCertificateData(certificateData, forDomain: domain)
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
            storeCertificateData(certificateData, forDomain: domain)
            NotificationCenter.default.post(name: .acceptedServerCertificatesChanged, object: self)
            return (.useCredential, URLCredential(trust: serverTrust))
        case .undecided:
            return (.cancelAuthenticationChallenge, nil)
        }
    }

    private func handleBasicAuth(challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let credential = URLCredential(user: connectionConfiguration.username, password: connectionConfiguration.password, persistence: .forSession)
        return (.useCredential, credential)
    }

    private func handleClientCertificateAuth(challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let certificateManager = ClientCertificateManager()
        let (disposition, credential) = certificateManager.evaluateTrust(with: challenge)
        return (disposition, credential)
    }

    // MARK: - SSL Certificate Handling

    private func initializeCertificatesStore() {
        os_log("Initializing cert store", log: .default, type: .info)
        loadTrustedCertificates()
        if trustedCertificates.isEmpty {
            os_log("No cert store, creating", log: .default, type: .info)
            trustedCertificates = [:]
            saveTrustedCertificates()
        } else {
            os_log("Loaded existing cert store", log: .default, type: .info)
        }
    }

    private func getPersistencePath() -> URL {
        #if os(watchOS)
        return URL.documentsDirectory.appendingPathComponent("trustedCertificates")
        #else
        let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.openhab.app")!
        return appGroupURL.appendingPathComponent("trustedCertificates")
        #endif
    }

    private func saveTrustedCertificates() {
        do {
            let data = try PropertyListEncoder().encode(trustedCertificates)
            try data.write(to: getPersistencePath())
        } catch {
            os_log("Could not save trusted certificates", log: .default)
        }
    }

    private func loadTrustedCertificates() {
        var decodableTrustedCertificates: [String: Data] = [:]
        do {
            let rawdata = try Data(contentsOf: getPersistencePath())
            let decoder = PropertyListDecoder()
            decodableTrustedCertificates = try decoder.decode([String: Data].self, from: rawdata)
            trustedCertificates = decodableTrustedCertificates
        } catch {
            // if Decodable fails, fall back to NSKeyedArchiver
            do {
                let rawdata = try Data(contentsOf: getPersistencePath())
                if let unarchivedTrustedCertificates = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSDictionary.self, NSString.self, NSData.self], from: rawdata) as? [String: Data] {
                    trustedCertificates = unarchivedTrustedCertificates
                    saveTrustedCertificates() // Ensure that data is written in new format
                }
            } catch {
                os_log("Could not load trusted certificates", log: .default)
            }
        }
    }

    private func storeCertificateData(_ certificate: CFData?, forDomain domain: String) {
        let certificateData = certificate as Data?
        trustedCertificates[domain] = certificateData
        saveTrustedCertificates()
    }

    private func certificateData(forDomain domain: String) -> CFData? {
        guard let certificateData = trustedCertificates[domain] else { return nil }
        return certificateData as CFData
    }

    private func getLeafCertificate(trust: SecTrust?) -> SecCertificate? {
        if let trust, SecTrustGetCertificateCount(trust) > 0,
           let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate] {
            return certificates[0]
        }
        return nil
    }

    private func waitForEvaluation() async -> CertificateEvaluateResult {
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
