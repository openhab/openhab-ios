//
//  OpenHABHTTPRequestOperation.swift
//  openHAB
//
//  Created by David O'Neill on 03/09/19.
//  Copyright (c) 2019 David O'Neill. All rights reserved.

import AFNetworking
import os.log

// https://medium.com/@AladinWay/write-a-networking-layer-in-swift-4-using-alamofire-5-and-codable-part-2-perform-request-and-b5c7ee2e012d
// Transition from AFNetworking to Alamofire 5.0
// SessionManager --> Session
// serverTrustPolicyManager --> serverTrustManager
// ServerTrustPolicyManager --> ServerTrustManager

// SessionStateProvider
// AFSecurityPolicy

private struct Certificates {

    static func getPersistensePath() -> String? {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        let filePath = URL(fileURLWithPath: documentsDirectory).appendingPathComponent("trustedCertificates").absoluteString
        return filePath
    }

    static func loadTrustedCertificates() {
        if let unarchive = NSKeyedUnarchiver.unarchiveObject(withFile: self.getPersistensePath() ?? "") as? [AnyHashable: Any] {
            trustedCertificates = unarchive
        }
    }

    static func storeCertificateData(_ certificate: CFData?, forDomain domain: String?) {
        let certificateData = certificate as Data?
        trustedCertificates[domain] = certificateData
        self.saveTrustedCertificates()
    }

    static func saveTrustedCertificates() {
        NSKeyedArchiver.archiveRootObject(trustedCertificates, toFile: self.getPersistensePath() ?? "")
    }

}

class OpenHABHTTPRequestOperation: AFHTTPRequestOperation {
    static var clientCertificateManager: ClientCertificateManager = ClientCertificateManager()

    init(request: URLRequest, delegate: AFRememberingSecurityPolicyDelegate?) {
        super.init(request: request)
        super.setWillSendRequestForAuthenticationChallenge { (connection: NSURLConnection, challenge: URLAuthenticationChallenge) in

            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                if self.securityPolicy.evaluateServerTrust(challenge.protectionSpace.serverTrust!, forDomain: challenge.protectionSpace.host) {
                    let credential = URLCredential.init(trust: challenge.protectionSpace.serverTrust!)
                    challenge.sender!.use(credential, for: challenge)
                } else {
                    challenge.sender!.cancel(challenge)
                }
            } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
                self.evaluateClientTrust(challenge: challenge)
            } else {
                if challenge.previousFailureCount == 0 {
                    if self.credential != nil {
                        challenge.sender!.use(self.credential!, for: challenge)
                    } else {
                        challenge.sender!.continueWithoutCredential(for: challenge)
                    }
                } else {
                    challenge.sender!.continueWithoutCredential(for: challenge)
                }
            }
        }

        let policy = AFRememberingSecurityPolicy(pinningMode: AFSSLPinningMode.none)
        policy.delegate = delegate

        let prefs = UserDefaults.standard
        let ignoreSSLCertificate = prefs.bool(forKey: "ignoreSSL")

        if ignoreSSLCertificate {
            os_log("Warning - ignoring invalid certificates", log: OSLog.remoteAccess, type: .info)
            policy.allowInvalidCertificates = true
            policy.validatesDomainName = false
        }
        self.securityPolicy = policy
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
}
