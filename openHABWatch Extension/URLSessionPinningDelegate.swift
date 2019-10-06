// Copyright (c) 2010-2019 Contributors to the openHAB project
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
import Security

// Inspired by https://code.tutsplus.com/articles/securing-communications-on-ios--cms-28529 and
// https://gist.github.com/daniel-rueda/132c1a556dad7cf6b734b59ed47a1f75

struct Certificate {
    let certificate: SecCertificate
    let data: Data
}

class CertificatePinningURLSessionDelegate: NSObject, URLSessionDelegate {
    var clientCertificateManager = ClientCertificateManager()

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void) {
        let protectionSpace = challenge.protectionSpace
        if protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust, let serverTrust = protectionSpace.serverTrust {
            if Preferences.ignoreSSL {
                let credential = URLCredential(trust: serverTrust)
                os_log("Warning - ignoring invalid certificates", log: OSLog.remoteAccess, type: .info)
                completionHandler(.useCredential, credential)
                return
            }

            // Set policy to validate domain
            let policy = SecPolicyCreateSSL(true, "yourdomain.com" as CFString)
            let policies = NSArray(object: policy)
            SecTrustSetPolicies(serverTrust, policies)

            let certificateCount = SecTrustGetCertificateCount(serverTrust)
            guard certificateCount > 0,
                let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }

            let serverCertificateData = SecCertificateCopyData(certificate) as Data
            let certificates = Certificate.localCertificates()
            for localCert in certificates {
                if localCert.validate(against: serverCertificateData, using: serverTrust) {
                    completionHandler(.useCredential, URLCredential(trust: serverTrust))
                    return // exit as soon as we found a match
                }
            }

            // No valid cert available
            completionHandler(.cancelAuthenticationChallenge, nil)

        } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            evaluateClientTrust(challenge: challenge)
        } else {
            if challenge.previousFailureCount == 0 {
                let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.useCredential, nil)
            }
        }
    }

    func evaluateClientTrust(challenge: URLAuthenticationChallenge) {
        let dns = challenge.protectionSpace.distinguishedNames
        if let dns = dns {
            let identity = clientCertificateManager.evaluateTrust(distinguishedNames: dns)
            if let identity = identity {
                let credential = URLCredential(identity: identity, certificates: nil, persistence: URLCredential.Persistence.forSession)
                challenge.sender!.use(credential, for: challenge)
                return
            }
        }
        // No client certificate available
        challenge.sender!.cancel(challenge)
    }
}

extension Certificate {
    static func localCertificates(with names: [String] = ["CertificateRenewed", "Certificate"],
                                  from bundle: Bundle = .main) -> [Certificate] {
        return names.lazy.map {
            guard let file = bundle.url(forResource: $0, withExtension: "cer"),
                let data = try? Data(contentsOf: file),
                let cert = SecCertificateCreateWithData(nil, data as CFData) else {
                return nil
            }
            return Certificate(certificate: cert, data: data)
        }
        .compactMap { $0 }
    }

    func validate(against certData: Data, using secTrust: SecTrust) -> Bool {
        let certArray = [certificate] as CFArray
        SecTrustSetAnchorCertificates(secTrust, certArray)

        // validates a certificate by verifying its signature plus the signatures of
        // the certificates in its certificate chain, up to the anchor certificate
        var result = SecTrustResultType.invalid
        SecTrustEvaluate(secTrust, &result)
        let isValid = (result == .unspecified || result == .proceed)

        // Validate host certificate against pinned certificate.
        return isValid && certData == data
    }
}
