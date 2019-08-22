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

var trustedCertificates: [String: Any] = [:]

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
        if trustedCertificates.isEmpty {
            os_log("No cert store, creating", log: .remoteAccess, type: .info)
            trustedCertificates = [:]
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
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: trustedCertificates, requiringSecureCoding: false)
            try data.write(to: URL(string: self.getPersistensePath() ?? "")!)
        } catch {
            os_log("Could not save trusted certificates", log: .default)
        }
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

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init() {
        super.init()

        let prefs = UserDefaults.standard
        let ignoreSSLCertificate = prefs.bool(forKey: "ignoreSSL")

        if ignoreSSLCertificate {
            os_log("Warning - ignoring invalid certificates", log: OSLog.remoteAccess, type: .info)
            self.allowInvalidCertificates = true
            self.validatesDomainName = false
        }
    }

    class func storeCertificateData(_ certificate: CFData?, forDomain domain: String) {
        let certificateData = certificate as Data?
        trustedCertificates[domain] = certificateData
        self.saveTrustedCertificates()
    }

    class func certificateData(forDomain domain: String) -> CFData? {
        guard let certificateData = trustedCertificates[domain] as? Data else { return nil  }
        return certificateData as CFData
    }

    class func loadTrustedCertificates() {
        do {
            let rawdata = try Data(contentsOf: URL( string: self.getPersistensePath() ?? "" )!)
            if let unarchive = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(rawdata) as? [String: Any] {
                trustedCertificates = unarchive
            }
        } catch {
            os_log("Could not load trusted certificates", log: .default)
        }

    }

    override func evaluateServerTrust(_ serverTrust: SecTrust?, forDomain domain: String?) -> Bool {
        // Evaluates trust received during SSL negotiation and checks it against known ones,
        // against policy setting to ignore certificate errors and so on.
        var evaluateResult: SecTrustResultType = .invalid
        guard let serverTrust = serverTrust else {
            return false
        }
        guard let domain = domain else {
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
        // Obtain certificate we have and compare it with the certificate presented by the server
        if let previousCertificateData = AFRememberingSecurityPolicy.certificateData(forDomain: domain) {
            if CFEqual(previousCertificateData, certificateData) {
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

    func evaluateClientTrust(challenge: URLAuthenticationChallenge) {
        let dns = challenge.protectionSpace.distinguishedNames
        if let dns = dns {
            let identity = OpenHABHTTPRequestOperation.clientCertificateManager.evaluateTrust(distinguishedNames: dns)
            if let identity = identity {
                let credential = URLCredential.init(identity: identity, certificates: nil, persistence: URLCredential.Persistence.forSession)
                challenge.sender!.use(credential, for: challenge)
                return
            }
        }
        // No client certificate available
        challenge.sender!.cancel(challenge)
    }

    func handleAuthenticationChallenge(challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
	if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
	    if self.evaluateServerTrust(challenge.protectionSpace.serverTrust!, forDomain: challenge.protectionSpace.host) {
		let credential = URLCredential.init(trust: challenge.protectionSpace.serverTrust!)
		return (URLSession.AuthChallengeDisposition.useCredential, credential)
	    } else {
		return (URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
	    }
	} else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
	    let dns = challenge.protectionSpace.distinguishedNames
	    if let dns = dns {
		let identity = OpenHABHTTPRequestOperation.clientCertificateManager.evaluateTrust(distinguishedNames: dns)
		if let identity = identity {
		    let credential = URLCredential.init(identity: identity, certificates: nil, persistence: URLCredential.Persistence.forSession)
		    return (URLSession.AuthChallengeDisposition.useCredential, credential)
		}
	    }
	    // No client certificate available
	    return (URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
	}
	return (URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
    }
}
