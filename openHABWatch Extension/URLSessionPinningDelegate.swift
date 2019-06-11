//
//  URLSessionPinningDelegate.swift
//  openHABWatch Extension
//
//  Created by Tim Müller-Seydlitz on 11.06.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation
import Security

// Inspired by https://code.tutsplus.com/articles/securing-communications-on-ios--cms-28529 and
// https://gist.github.com/daniel-rueda/132c1a556dad7cf6b734b59ed47a1f75

struct Certificate {
    let certificate: SecCertificate
    let data: Data
}

extension Certificate {
    static func localCertificates(with names: [String] = ["CertificateRenewed", "Certificate"],
                                  from bundle: Bundle = .main) -> [Certificate] {
        return names.lazy.map({
            guard let file = bundle.url(forResource: $0, withExtension: "cer"),
                let data = try? Data(contentsOf: file),
                let cert = SecCertificateCreateWithData(nil, data as CFData) else {
                    return nil
            }
            return Certificate(certificate: cert, data: data)
        }).compactMap({$0})
    }

    func validate(against certData: Data, using secTrust: SecTrust) -> Bool {
        let certArray = [certificate] as CFArray
        SecTrustSetAnchorCertificates(secTrust, certArray)

        //validates a certificate by verifying its signature plus the signatures of
        // the certificates in its certificate chain, up to the anchor certificate
        var result = SecTrustResultType.invalid
        SecTrustEvaluate(secTrust, &result)
        let isValid = (result == .unspecified || result == .proceed)

        //Validate host certificate against pinned certificate.
        return isValid && certData == self.data
    }
}

class CertificatePinningURLSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void) {
        guard let serverTrust = challenge.protectionSpace.serverTrust,
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
        }

        //Set policy to validate domain
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
    }
}
