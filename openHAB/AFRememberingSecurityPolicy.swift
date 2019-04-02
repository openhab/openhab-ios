//  Converted to Swift 4 by Swiftify v4.2.28153 - https://objectivec2swift.com/
//
//  AFRememberingSecurityPolicy.swift
//  openHAB
//
//  Created by Victor Belov on 14/07/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

import AFNetworking
import os.log

protocol AFRememberingSecurityPolicyDelegate: NSObjectProtocol {
    // delegate should ask user for a decision on what to do with invalid certificate
    func evaluateServerTrust(_ policy: AFRememberingSecurityPolicy?, summary certificateSummary: String?, forDomain domain: String?)
    // certificate received from openHAB doesn't match our record, ask user for a decision
    func evaluateCertificateMismatch(_ policy: AFRememberingSecurityPolicy?, summary certificateSummary: String?, forDomain domain: String?)
}

var trustedCertificates: [AnyHashable: Any] = [:]

func SecTrustGetLeafCertificate(trust: SecTrust?) -> SecCertificate? {
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

class AFRememberingSecurityPolicy: AFSecurityPolicy {
    class func initializeCertificatesStore() {
        os_log("Initializing cert store", log: .remoteAccess, type: .info)
        self.loadTrustedCertificates()
        if trustedCertificates.count == 0 {
            os_log("No cert store, creating", log: .remoteAccess, type: .info)
            trustedCertificates = [AnyHashable: Any]()
            //        [trustedCertificates setObject:@"Bulk" forKey:@"Bulk id to make it non-empty"];
            self.saveTrustedCertificates()
        } else {
            os_log("Loaded existing cert store", log: .remoteAccess, type: .info)
        }
    }

    class func getPersistensePath() -> String? {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        let filePath = URL(fileURLWithPath: documentsDirectory).appendingPathComponent("trustedCertificates").absoluteString
        return filePath
    }

    class func saveTrustedCertificates() {
        NSKeyedArchiver.archiveRootObject(trustedCertificates, toFile: self.getPersistensePath() ?? "")
    }

    // Handle the different responses of the user
    // Ideal for transfer to Result type of swift 5.0
    enum EvaluateResult {
        case undecided
        case deny
        case permitOnce
        case permitAlways
    }
    var evaluateResult: EvaluateResult = .undecided
    weak var delegate: AFRememberingSecurityPolicyDelegate?

    // Init an AFRememberingSecurityPolicy and set ignore certificates setting
    init(ignoreCertificates: Bool) {
        super.init()
        allowInvalidCertificates = ignoreCertificates
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(pinningMode: AFSSLPinningMode) {
        super.init()
    }

    class func storeCertificateData(_ certificate: CFData?, forDomain domain: String?) {
        //    NSData *certificateData = [NSKeyedArchiver archivedDataWithRootObject:(__bridge id)(certificate)];
        let certificateData = certificate as Data?
        trustedCertificates[domain] = certificateData
        self.saveTrustedCertificates()
    }

    class func certificateData(forDomain domain: String?) -> CFData? {
        let certificateData = trustedCertificates[domain] as? Data
        if certificateData == nil {
            return nil
        }
        let certificate = certificateData?.withUnsafeBytes {dataBytes in
            CFDataCreate(nil, dataBytes, (certificateData?.count ?? 0))
        }
        //    CFDataRef certificate = SecCertificateCopyData((__bridge CFDataRef)([NSKeyedUnarchiver unarchiveObjectWithData:certificateData]));
        return certificate
    }

    class func loadTrustedCertificates() {
        if let unarchive = NSKeyedUnarchiver.unarchiveObject(withFile: self.getPersistensePath() ?? "") as? [AnyHashable: Any] {
            trustedCertificates = unarchive
        }
    }

    override func evaluateServerTrust(_ serverTrust: SecTrust?, forDomain domain: String?) -> Bool {
        // Evaluates trust received during SSL negotiation and checks it against known ones,
        // against policy setting to ignore certificate errors and so on.
        var evaluateResult: SecTrustResultType = .invalid
        guard let serverTrust = serverTrust else {
            return false
        }
        SecTrustEvaluate(serverTrust, &evaluateResult)
        if evaluateResult == .unspecified || evaluateResult == .proceed || allowInvalidCertificates {
            // This means system thinks this is a legal/usable certificate, just permit the connection
            return true
        }
        let certificate = SecTrustGetLeafCertificate(trust: serverTrust)
        let certificateSummary = SecCertificateCopySubjectSummary(certificate!)
        let certificateData = SecCertificateCopyData(certificate!)
        // If we have a certificate for this domain
        if AFRememberingSecurityPolicy.certificateData(forDomain: domain) != nil {
            // Obtain certificate we have and compare it with the certificate presented by the server
            let previousCertificateData = AFRememberingSecurityPolicy.certificateData(forDomain: domain)
            let success = CFEqual(previousCertificateData, certificateData)
            if success {
                // If certificate matched one in our store - permit this connection
                return true
            } else {
                // We have a certificate for this domain in our memory of decisions, but the certificate we've got now
                // differs. We need to warn user about possible MiM attack and wait for users decision.
                // TODO: notify user and wait for decision
                if delegate != nil {
                    self.evaluateResult = .undecided
                    delegate?.evaluateCertificateMismatch(self, summary: certificateSummary as String?, forDomain: domain)
                    while self.evaluateResult == .undecided {
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                    switch self.evaluateResult {
                    case .deny:
                        // User decided to abort connection
                        return false
                    case .permitOnce:
                        // User decided to accept invalid certificate once
                        return true
                    case .permitAlways:
                        // User decided to accept invalid certificate and remember decision
                        // Add certificate to storage
                        AFRememberingSecurityPolicy.storeCertificateData(certificateData, forDomain: domain)
                        return true
                    case .undecided:
                        // Something went wrong, abort connection
                        return false
                    }
                }
                return false
            }
        }
        // Warn user about invalid certificate and wait for user's decision
        if delegate != nil {
            // Delegate should ask user for decision
            self.evaluateResult = .undecided
            delegate?.evaluateServerTrust(self, summary: certificateSummary as String?, forDomain: domain)
            // Wait until we get response from delegate with user's decision
            while self.evaluateResult == .undecided {
                Thread.sleep(forTimeInterval: 0.1)
            }
            switch self.evaluateResult {
            case .deny:
                // User decided to abort connection
                return false
            case .permitOnce:
                // User decided to accept invalid certificate once
                return true
            case .permitAlways:
                // User decided to accept invalid certificate and remember decision
                // Add certificate to storage
                AFRememberingSecurityPolicy.storeCertificateData(certificateData, forDomain: domain)
                return true
            case .undecided:
                return false
            }
        }
        // We have no way of handling it so no access!
        return false
    }
}
