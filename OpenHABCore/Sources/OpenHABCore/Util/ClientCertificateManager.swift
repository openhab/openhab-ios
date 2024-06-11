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

import Foundation
import os.log
import Security

public protocol ClientCertificateManagerDelegate: AnyObject {
    // delegate should ask user for a decision on whether to import the client certificate into the keychain
    func askForClientCertificateImport(_ clientCertificateManager: ClientCertificateManager?)
    // delegate should ask user for the export password used to decode the PKCS#12
    func askForCertificatePassword(_ clientCertificateManager: ClientCertificateManager?)
    // delegate should alert the user that an error occured importing the certificate
    func alertClientCertificateError(_ clientCertificateManager: ClientCertificateManager?, errMsg: String)
}

public class ClientCertificateManager {
    private var importingRawCert: Data?
    private var importingIdentity: SecIdentity?
    private var importingCertChain: [SecCertificate]?
    private var importingPassword: String?

    weak var delegate: ClientCertificateManagerDelegate?

    public var clientIdentities: [SecIdentity] = []

    init() {
        loadFromKeychain()
    }

    public func loadFromKeychain() {
        let getIdentityQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var items: CFTypeRef?
        let status = SecItemCopyMatching(getIdentityQuery as CFDictionary, &items)
        if status == errSecSuccess {
            clientIdentities = items as! [SecIdentity]
        }
    }

    public func getIdentityName(index: Int) -> String {
        if index >= 0, index < clientIdentities.count {
            let identity = clientIdentities[index]
            var cert: SecCertificate?
            SecIdentityCopyCertificate(identity, &cert)
            if let subject = SecCertificateCopySubjectSummary(cert!) {
                return subject as String
            }
        }
        return ""
    }

    public func evaluateTrust(distinguishedNames: [Data]) -> SecIdentity? {
        // Search the keychain for an identity that matches the DN of the certificate being requested by the server
        let getIdentityQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecMatchIssuers as String: distinguishedNames
        ]
        var identity: CFTypeRef?
        let status = SecItemCopyMatching(getIdentityQuery as CFDictionary, &identity)
        if status == errSecSuccess {
            return (identity as! SecIdentity)
        }
        return nil
    }

    public func deleteFromKeychain(index: Int) -> OSStatus {
        let identity = clientIdentities[index]
        clientIdentities.remove(at: index)
        let status = deleteFromKeychain(identity)
        if status != noErr {
            loadFromKeychain()
        }
        return status
    }

    public func deleteFromKeychain(_ identity: SecIdentity) -> OSStatus {
        var cert: SecCertificate?
        SecIdentityCopyCertificate(identity, &cert)
        var key: SecKey?
        SecIdentityCopyPrivateKey(identity, &key)

        let deleteCertQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: cert!
        ]
        var status = SecItemDelete(deleteCertQuery as NSDictionary)
        os_log("SecItemDelete(cert) result=%{PUBLIC}d", log: .default, type: .info, status)
        if status == noErr {
            let deleteKeyQuery: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecValueRef as String: key!
            ]
            status = SecItemDelete(deleteKeyQuery as NSDictionary)
            os_log("SecItemDelete(key) result=%{PUBLIC}d", log: .default, type: .info, status)
        }

        // Figure out which certs in the certificate chain also need to be removed.
        // There may be more than one identity which requires a specific certificate
        // in its issuer chain.  Build a reference count map of all the cert dependencies,
        // remove the references to the identity being deleted and then remove all
        // certs which have a ref count of 0.
        let refCountMap = buildCertChainRefCountMap()
        if let certChain = buildIdentityCertChain(cert: cert!) {
            for ct in certChain {
                let refCount = refCountMap[ct] ?? 0
                if refCount == 0 {
                    let deleteCertQuery: [String: Any] = [
                        kSecClass as String: kSecClassCertificate,
                        kSecValueRef as String: ct
                    ]
                    let status = SecItemDelete(deleteCertQuery as NSDictionary)
                    let summary = SecCertificateCopySubjectSummary(ct) as String? ?? ""
                    os_log("SecItemDelete(certChain) %s result=%{PUBLIC}d", log: .default, type: .info, summary, status)
                }
            }
        }
        return status
    }

    func buildCertChainRefCountMap() -> [SecCertificate: Int] {
        var refCounts = [SecCertificate: Int]()
        for identity in clientIdentities {
            var cert: SecCertificate?
            SecIdentityCopyCertificate(identity, &cert)
            guard let certChain = buildIdentityCertChain(cert: cert!) else { continue }
            for ct in certChain {
                if let count = refCounts[ct] {
                    refCounts[ct] = count + 1
                } else {
                    refCounts[ct] = 1
                }
            }
        }
        return refCounts
    }

    public func startImportClientCertificate(url: URL) -> Bool {
        do {
            // Import PKCS12 client cert
            importingRawCert = try Data(contentsOf: url)

            if let delegate {
                delegate.askForClientCertificateImport(self)
            } else {
                return false
            }
        } catch {
            os_log("Unable to read certificate from URL", log: .default, type: .info)
            return false
        }
        return true
    }

    public func clientCertificateAccepted(password: String?) {
        // Import PKCS12 client cert
        importingPassword = password
        let status = decodePKCS12()
        switch status {
        case noErr:
            addClientCertificateToKeychain()
        case errSecAuthFailed:
            delegate?.askForCertificatePassword(self)
        default:
            let errMsg = String(format: NSLocalizedString("unable_to_decode_certificate", comment: ""), "\(status)")
            delegate?.alertClientCertificateError(self, errMsg: errMsg)
        }
    }

    public func clientCertificateRejected() {
        importingIdentity = nil
        importingRawCert = nil
        importingPassword = nil
    }

    func addClientCertificateToKeychain() {
        var clientCert: SecCertificate?
        var clientKey: SecKey?
        SecIdentityCopyPrivateKey(importingIdentity!, &clientKey)
        SecIdentityCopyCertificate(importingIdentity!, &clientCert)

        // Add identity's cert
        let addCertQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: clientCert!
        ]
        var status = SecItemAdd(addCertQuery as NSDictionary, nil)
        os_log("SecItemAdd(cert) result=%{PUBLIC}d", log: .default, type: .info, status)
        if status == noErr {
            let addKeyQuery: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrIsPermanent as String: true,
                kSecValueRef as String: clientKey!
            ]
            status = SecItemAdd(addKeyQuery as NSDictionary, nil)
            os_log("SecItemAdd(key) result=%{PUBLIC}d", log: .default, type: .info, status)

            // Add  the cert chain
            if let importingCertChain {
                for cert in importingCertChain where cert != clientCert {
                    let addCertQuery: [String: Any] = [
                        kSecClass as String: kSecClassCertificate,
                        kSecValueRef as String: cert
                    ]
                    status = SecItemAdd(addCertQuery as NSDictionary, nil)
                    os_log("SecItemAdd(certChain) result=%{PUBLIC}d", log: .default, type: .info, status)
                    if status == errSecDuplicateItem {
                        // Ignore duplicates as there may already be other client certs with an overlapping issuer chain
                        status = noErr
                    } else if status != noErr {
                        break
                    }
                }
            }
        }

        // Refresh identities from the keychain
        loadFromKeychain()

        if status != noErr {
            _ = deleteFromKeychain(importingIdentity!)

            var errMsg = String(format: NSLocalizedString("unable_to_add_certificate", comment: ""), "\(status)")
            if status == errSecDuplicateItem {
                errMsg = NSLocalizedString("certficate_exists", comment: "")
            }
            delegate?.alertClientCertificateError(self, errMsg: errMsg)
        }
    }

    private func decodePKCS12() -> OSStatus {
        // Import PKCS12 client cert
        var importResult: CFArray?
        let status = SecPKCS12Import(importingRawCert! as CFData, [kSecImportExportPassphrase as String: importingPassword ?? ""] as NSDictionary, &importResult)
        if status == noErr {
            // Extract the certifcate and private key
            let identityDictionaries = importResult as! [[String: Any]]
            importingIdentity = identityDictionaries[0][kSecImportItemIdentity as String] as! SecIdentity?
            importingCertChain = identityDictionaries[0][kSecImportItemCertChain as String] as! [SecCertificate]?
        } else {
            os_log("SecPKCS12Import failed; result=%{PUBLIC}d", log: .default, type: .info, status)
        }
        return status
    }

    func evaluateTrust(with challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let dns = challenge.protectionSpace.distinguishedNames
        if let dns {
            let identity = evaluateTrust(distinguishedNames: dns)
            if let identity {
                var cert: SecCertificate?
                SecIdentityCopyCertificate(identity, &cert)
                let certChain = buildIdentityCertChain(cert: cert!)
                let credential = URLCredential(identity: identity, certificates: certChain, persistence: URLCredential.Persistence.forSession)
                return (.useCredential, credential)
            }
        }
        return (.cancelAuthenticationChallenge, nil)
    }

    func buildIdentityCertChain(cert: SecCertificate) -> [SecCertificate]? {
        let certArray = [cert]
        var optionalTrust: SecTrust?
        let policy = SecPolicyCreateSSL(false, nil)
        let status = SecTrustCreateWithCertificates(
            certArray as AnyObject,
            policy,
            &optionalTrust
        )
        guard status == errSecSuccess else { return nil }
        let trust = optionalTrust!
        var trustResult = SecTrustResultType.proceed
        if #available(iOS 12.0, *) {
            var trustError: CFError?
            if SecTrustEvaluateWithError(trust, &trustError) != true {
                SecTrustGetTrustResult(trust, &trustResult)
            }
        } else {
            SecTrustEvaluate(trust, &trustResult)
        }

        let chainSize = SecTrustGetCertificateCount(trust)

        if trustResult == .recoverableTrustFailure, chainSize > 1 {
            trustResult = SecTrustResultType.proceed
            let rootCA = SecTrustGetCertificateAtIndex(trust, chainSize - 1)
            let anchors = [rootCA]
            os_log("Setting anchor for trust evaluation to %s", log: .default, type: .info, rootCA.debugDescription)
            SecTrustSetAnchorCertificates(trust, anchors as CFArray)
            if #available(iOS 12.0, *) {
                var trustError: CFError?
                if SecTrustEvaluateWithError(trust, &trustError) != true {
                    os_log("Trust evaluation failed building client certificate chain after anchor has been set: %s", log: .default, type: .info, trustError.debugDescription)
                    SecTrustGetTrustResult(trust, &trustResult)
                }
            } else {
                if SecTrustEvaluate(trust, &trustResult) != errSecSuccess {
                    os_log("Trust evaluation failed building client certificate chain after anchor has been set: SecTrustResultType=%u", log: .default, type: .info, trustResult.rawValue)
                }
            }
        }
        if trustResult != .proceed {
            return nil
        }

        var certChain: [SecCertificate] = []
        for ix in 0 ... chainSize - 1 {
            guard let ct = SecTrustGetCertificateAtIndex(trust, ix) else { return nil }
            if ct != cert {
                certChain.append(ct)
            }
        }
        return certChain
    }
}
