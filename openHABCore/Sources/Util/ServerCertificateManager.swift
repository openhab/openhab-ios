// Copyright (c) 2010-2020 Contributors to the openHAB project
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
    // Ideal for transfer to Result type of swift 5.0
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

    var evaluateResultSemaphore = DispatchSemaphore(value: 1)

    weak var delegate: ServerCertificateManagerDelegate?
    // ignoreSSL is a synonym for allowInvalidCertificates, ignoreCertificates
    public var ignoreSSL: Bool = false
    public var trustedCertificates: [String: Any] = [:]

    // Init a ServerCertificateManager and set ignore certificates setting
    public init(ignoreSSL: Bool) {
        super.init(evaluators: [:])
        self.ignoreSSL = ignoreSSL
        initializeCertificatesStore()
    }

    func initializeCertificatesStore() {
        os_log("Initializing cert store", log: .remoteAccess, type: .info)
        loadTrustedCertificates()
        if trustedCertificates.isEmpty {
            os_log("No cert store, creating", log: .remoteAccess, type: .info)
            trustedCertificates = [:]
            saveTrustedCertificates()
        } else {
            os_log("Loaded existing cert store", log: .remoteAccess, type: .info)
        }
    }

    func getPersistensePath() -> String? {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        let filePath = URL(fileURLWithPath: documentsDirectory).appendingPathComponent("trustedCertificates").absoluteString
        return filePath
    }

    public func saveTrustedCertificates() {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: trustedCertificates, requiringSecureCoding: false)
            try data.write(to: URL(string: getPersistensePath() ?? "")!)
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
        guard let certificateData = trustedCertificates[domain] as? Data else { return nil }
        return certificateData as CFData
    }

    func loadTrustedCertificates() {
        do {
            let rawdata = try Data(contentsOf: URL(string: getPersistensePath() ?? "")!)
            if let unarchive = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(rawdata) as? [String: Any] {
                trustedCertificates = unarchive
            }
        } catch {
            os_log("Could not load trusted certificates", log: .default)
        }
    }

    func evaluateTrust(challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
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
                if delegate != nil {
                    self.evaluateResult = .undecided
                    delegate?.evaluateCertificateMismatch(self, summary: certificateSummary as String?, forDomain: domain)
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
                        delegate?.acceptedServerCertificatesChanged(self)
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
        if delegate != nil {
            // Delegate should ask user for decision
            self.evaluateResult = .undecided
            delegate?.evaluateServerTrust(self, summary: certificateSummary as String?, forDomain: domain)
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
                delegate?.acceptedServerCertificatesChanged(self)
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

        if let trust = trust {
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
