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
import os.log

public protocol ServerCertificateManagerDelegate: NSObjectProtocol {
    // delegate should ask user for a decision on what to do with invalid certificate
    func evaluateServerTrust(_ policy: ServerCertificateManager?, summary certificateSummary: String?, forDomain domain: String?)
    // certificate received from openHAB doesn't match our record, ask user for a decision
    func evaluateCertificateMismatch(_ policy: ServerCertificateManager?, summary certificateSummary: String?, forDomain domain: String?)
    // notify delegate that the certificagtes that a user is willing to trust has changed
    func acceptedServerCertificatesChanged(_ policy: ServerCertificateManager?)
}

public class ServerCertificateManager: ServerTrustManager, ServerTrustEvaluating {
    // Handle the different responses of the user
    public enum EvaluateResult {
        case undecided
        case deny
        case permitOnce
        case permitAlways
    }

    public var evaluateResult: EvaluateResult = .undecided {
        didSet {
            if evaluateResult != .undecided {
                evaluateResultSemaphore.signal()
            }
        }
    }

    private let evaluateResultSemaphore = DispatchSemaphore(value: 0)

    weak var delegate: ServerCertificateManagerDelegate?
    // ignoreSSL is a synonym for allowInvalidCertificates, ignoreCertificates
    public var ignoreSSL = false
    public var trustedCertificates: [String: Data] = [:]

    // Init a ServerCertificateManager and set ignore certificates setting
    public init(ignoreSSL: Bool) {
        super.init(evaluators: [:])
        self.ignoreSSL = ignoreSSL
    }

    func initializeCertificatesStore() {
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
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.es.spaphone.openhab")!.appendingPathComponent("trustedCertificates")
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

    func evaluateTrust(with challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        do {
            let serverTrust = challenge.protectionSpace.serverTrust!
            try evaluate(serverTrust, forHost: challenge.protectionSpace.host)
            return (.useCredential, URLCredential(trust: serverTrust))
        } catch {
            return (.cancelAuthenticationChallenge, nil)
        }
    }

    func wrapperSecTrustEvaluate(serverTrust: SecTrust) -> SecTrustResultType {
        var result: SecTrustResultType = .invalid

        if #available(iOS 12.0, *) {
            // SecTrustEvaluate is deprecated.
            // Wrap new API to have same calling pattern as we had prior to deprecation.

            var error: CFError?
            _ = SecTrustEvaluateWithError(serverTrust, &error)
            SecTrustGetTrustResult(serverTrust, &result)
            return result

        } else {
            SecTrustEvaluate(serverTrust, &result)
            return result
        }
    }

    public func evaluate(_ serverTrust: SecTrust, forHost domain: String) throws {
        // Evaluates trust received during SSL negotiation and checks it against known ones,
        // against policy setting to ignore certificate errors and so on.
        let evaluateResult = wrapperSecTrustEvaluate(serverTrust: serverTrust)

        if evaluateResult.isAny(of: .unspecified, .proceed) || ignoreSSL {
            // This means system thinks this is a legal/usable certificate, just permit the connection
            return
        }
        let certificate = getLeafCertificate(trust: serverTrust)
        let certificateSummary = SecCertificateCopySubjectSummary(certificate!)
        let certificateData = SecCertificateCopyData(certificate!)
        // If we have a certificate for this domain
        // Obtain certificate we have and compare it with the certificate presented by the server
        if let previousCertificateData = self.certificateData(forDomain: domain) {
            if CFEqual(previousCertificateData, certificateData) {
                // If certificate matched one in our store - permit this connection
                return
            } else {
                // We have a certificate for this domain in our memory of decisions, but the certificate we've got now
                // differs. We need to warn user about possible MiM attack and wait for users decision.
                // TODO: notify user and wait for decision
                if let delegate {
                    self.evaluateResult = .undecided
                    delegate.evaluateCertificateMismatch(self, summary: certificateSummary as String?, forDomain: domain)
                    evaluateResultSemaphore.wait()
                    switch self.evaluateResult {
                    case .deny:
                        // User decided to abort connection
                        throw AFError.serverTrustEvaluationFailed(reason: .noCertificatesFound)
                    case .permitOnce:
                        // User decided to accept invalid certificate once
                        return
                    case .permitAlways:
                        // User decided to accept invalid certificate and remember decision
                        // Add certificate to storage
                        storeCertificateData(certificateData, forDomain: domain)
                        delegate.acceptedServerCertificatesChanged(self)
                        return
                    case .undecided:
                        // Something went wrong, abort connection
                        throw AFError.serverTrustEvaluationFailed(reason: .noCertificatesFound)
                    }
                }
                throw AFError.serverTrustEvaluationFailed(reason: .noCertificatesFound)
            }
        }
        // Warn user about invalid certificate and wait for user's decision
        if let delegate {
            // Delegate should ask user for decision
            self.evaluateResult = .undecided
            delegate.evaluateServerTrust(self, summary: certificateSummary as String?, forDomain: domain)
            // Wait until we get response from delegate with user's decision
            evaluateResultSemaphore.wait()
            switch self.evaluateResult {
            case .deny:
                // User decided to abort connection
                throw AFError.serverTrustEvaluationFailed(reason: .noCertificatesFound)
            case .permitOnce:
                // User decided to accept invalid certificate once
                return
            case .permitAlways:
                // User decided to accept invalid certificate and remember decision
                // Add certificate to storage
                storeCertificateData(certificateData, forDomain: domain)
                delegate.acceptedServerCertificatesChanged(self)
                return
            case .undecided:
                throw AFError.serverTrustEvaluationFailed(reason: .noCertificatesFound)
            }
        }
        // We have no way of handling it so no access!
        throw AFError.serverTrustEvaluationFailed(reason: .noCertificatesFound)
    }

    func getLeafCertificate(trust: SecTrust?) -> SecCertificate? {
        // Returns the leaf certificate from a SecTrust object (that is always the
        // certificate at index 0).
        var result: SecCertificate?

        if let trust {
            if SecTrustGetCertificateCount(trust) > 0 {
                result = SecTrustGetCertificateAtIndex(trust, 0)
                return result
            } else {
                return nil
            }
        } else {
            return nil
        }
    }

    override public func serverTrustEvaluator(forHost host: String) -> ServerTrustEvaluating? {
        self as ServerTrustEvaluating
    }
}
