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
import os.log

// public protocol ServerCertificateManagerDelegate: NSObjectProtocol {
//    // delegate should ask user for a decision on what to do with invalid certificate
//    func evaluateServerTrust(_ policy: ServerCertificateManager?, summary certificateSummary: String?, forDomain domain: String?)
//    // certificate received from openHAB doesn't match our record, ask user for a decision
//    func evaluateCertificateMismatch(_ policy: ServerCertificateManager?, summary certificateSummary: String?, forDomain domain: String?)
//    // notify delegate that the certificagtes that a user is willing to trust has changed
//    func acceptedServerCertificatesChanged(_ policy: ServerCertificateManager?)
// }

public protocol ServerCertificateManagerDelegate: AnyObject {
    // delegate should ask user for a decision on what to do with invalid certificate
    func evaluateServerTrust(summary certificateSummary: String?, forDomain domain: String?) async -> ServerCertificateManager.EvaluateResult
    // certificate received from openHAB doesn't match our record, ask user for a decision
    func evaluateCertificateMismatch(summary certificateSummary: String?, forDomain domain: String?) async -> ServerCertificateManager.EvaluateResult
    // notify delegate that the certificagtes that a user is willing to trust has changed
    func acceptedServerCertificatesChanged()
}

enum ServerCertificateManagerError: Error {
    case serverTrustEvaluationFailed
}

public class ServerCertificateManager { // ServerTrustManager, ServerTrustEvaluating {
    // Handle the different responses of the user
    public enum EvaluateResult: Sendable {
        case undecided
        case deny
        case permitOnce
        case permitAlways
    }

//    public var evaluateResult: EvaluateResult = .undecided {
//        didSet {
//            if evaluateResult != .undecided {
//                evaluateResultSemaphore.signal()
//            }
//        }
//    }

    weak var delegate: ServerCertificateManagerDelegate?
    // ignoreSSL is a synonym for allowInvalidCertificates, ignoreCertificates
    public var ignoreSSL = false
    public var trustedCertificates: [String: Data] = [:]

    // Init a ServerCertificateManager and set ignore certificates setting
    public init(ignoreSSL: Bool = false) {
//        super.init(evaluators: [:])
        self.ignoreSSL = ignoreSSL

        os_log("Initializing cert store", log: .remoteAccess, type: .info)
        loadTrustedCertificates()
        if trustedCertificates.isEmpty {
            os_log("No cert store, creating", log: .remoteAccess, type: .info)
            trustedCertificates = [:]
            //        [trustedCertificates setObject:@"Bulk" forKey:@"Bulk id to make it non-empty"];
            saveTrustedCertificates()
        } else {
            os_log("Loaded existing cert store", log: .remoteAccess, type: .info)
        }
    }

    func getPersistensePath() -> URL {
        #if os(watchOS)
        let documentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return URL(fileURLWithPath: documentsDirectory).appendingPathComponent("trustedCertificates")
        #else
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.openhab.app")!.appendingPathComponent("trustedCertificates")
        #endif
    }

    public func saveTrustedCertificates() {
        do {
            let data = try PropertyListEncoder().encode(trustedCertificates)
            try data.write(to: getPersistensePath())
        } catch {
            os_log("Could not save trusted certificates", log: .default)
        }
    }

    func storeCertificateData(_ certificate: CFData?, forDomain domain: String) {
        let certificateData = certificate as Data?
        trustedCertificates[domain] = certificateData
        saveTrustedCertificates()
    }

    func certificateData(forDomain domain: String) -> CFData? {
        guard let certificateData = trustedCertificates[domain] else { return nil }
        return certificateData as CFData
    }

    func loadTrustedCertificates() {
        var decodableTrustedCertificates: [String: Data] = [:]
        do {
            let rawdata = try Data(contentsOf: getPersistensePath())
            let decoder = PropertyListDecoder()
            decodableTrustedCertificates = try decoder.decode([String: Data].self, from: rawdata)
            trustedCertificates = decodableTrustedCertificates
        } catch {
            // if Decodable fails, fall back to NSKeyedArchiver. Handling can be removed when customer base is migrated
            do {
                let rawdata = try Data(contentsOf: getPersistensePath())
                if let unarchivedTrustedCertificates = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSDictionary.self, NSString.self, NSData.self], from: rawdata) as? [String: Data] {
                    trustedCertificates = unarchivedTrustedCertificates
                    saveTrustedCertificates() // Ensure that data is written in new format to take this path only once
                } else {
                    return
                }
            } catch {
                os_log("Could not load trusted unarchived certificates", log: .default)
            }
            os_log("Could not load trusted codable certificates", log: .default)
        }
    }

    func evaluateTrust(with challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        do {
            let serverTrust = challenge.protectionSpace.serverTrust!
            try await evaluate(serverTrust, forHost: challenge.protectionSpace.host)
            return (.useCredential, URLCredential(trust: serverTrust))
        } catch {
            return (.cancelAuthenticationChallenge, nil)
        }
    }

    func wrapperSecTrustEvaluate(serverTrust: SecTrust) -> SecTrustResultType {
        var result: SecTrustResultType = .invalid

        // SecTrustEvaluate is deprecated.
        // Wrap new API to have same calling pattern as we had prior to deprecation.

        var error: CFError?
        _ = SecTrustEvaluateWithError(serverTrust, &error)
        SecTrustGetTrustResult(serverTrust, &result)
        return result
    }

    // Evaluates trust received during SSL negotiation and checks it against known ones,
    // against policy setting to ignore certificate errors and so on.
    public func evaluate(_ serverTrust: SecTrust, forHost domain: String) async throws {
        let evaluateResult = wrapperSecTrustEvaluate(serverTrust: serverTrust)

        // This means that system thinks this is a legal/usable certificate, just permit the connection
        if evaluateResult.isAny(of: .unspecified, .proceed) || ignoreSSL {
            return
        }

        guard let certificate = getLeafCertificate(trust: serverTrust) else {
            throw ServerCertificateManagerError.serverTrustEvaluationFailed
        }

        let certificateSummary = SecCertificateCopySubjectSummary(certificate)
        let certificateData = SecCertificateCopyData(certificate)

        // If we have a certificate for this domain
        // Obtain certificate we have and compare it with the certificate presented by the server
        if let previousData = self.certificateData(forDomain: domain), CFEqual(previousData, certificateData) {
            // If certificate matched one in our store - permit this connection
            return // trusted
        }

        guard let delegate else {
            throw ServerCertificateManagerError.serverTrustEvaluationFailed
        }

        let decision: EvaluateResult = if self.certificateData(forDomain: domain) != nil {
            // mismatch, we have a certificate for this domain in our memory of decisions, but the certificate we've got now
            // differs. We need to warn user about possible MiM attack and wait for users decision.
            await delegate.evaluateCertificateMismatch(summary: certificateSummary as String?, forDomain: domain)
        } else {
            // new untrusted cert, warn user about invalid certificate and wait for user's decision
            await delegate.evaluateServerTrust(summary: certificateSummary as String?, forDomain: domain)
        }

        switch decision {
        case .deny, .undecided:
            // User decided to abort connection or something went wrong, abort connection
            throw ServerCertificateManagerError.serverTrustEvaluationFailed
        case .permitOnce:
            // User decided to accept invalid certificate once
            return
        case .permitAlways:
            // User decided to accept invalid certificate and remember decision
            // Add certificate to storage
            storeCertificateData(certificateData, forDomain: domain)
            delegate.acceptedServerCertificatesChanged()
            return
        }
    }

    func getLeafCertificate(trust: SecTrust?) -> SecCertificate? {
        // Returns the leaf certificate from a SecTrust object (that is always the
        // certificate at index 0).

        if let trust, SecTrustGetCertificateCount(trust) > 0, let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate] {
            certificates[0]
        } else {
            nil
        }
    }
}
