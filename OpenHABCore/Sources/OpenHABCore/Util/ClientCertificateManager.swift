// Copyright (c) 2010-2026 Contributors to the openHAB project
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

@MainActor
public protocol ClientCertificateManagerDelegate: AnyObject {
    // delegate should ask user for a decision on whether to import the client certificate into the keychain
    func askForClientCertificateImport(_ clientCertificateManager: ClientCertificateManager?) async -> Bool
    // delegate should ask user for a decision on whether to import the client certificate into the keychain
    func askForCertificatePassword(_ clientCertificateManager: ClientCertificateManager?) async -> String?
    // delegate should alert the user that an error occured importing the certificate
    func alertClientCertificateError(_ clientCertificateManager: ClientCertificateManager?, errMsg: String) async
}

public class ClientCertificateManager {
    public var importingRawCert: Data?
    public var importingIdentity: SecIdentity?
    private var importingCertChain: [SecCertificate]?
    public var importingPassword: String?

    public weak var delegate: (any ClientCertificateManagerDelegate)?

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
        Logger.clientCert.info("SecItemDelete(cert) result = \(status) ")
        if status == noErr {
            let deleteKeyQuery: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecValueRef as String: key!
            ]
            status = SecItemDelete(deleteKeyQuery as NSDictionary)
            Logger.clientCert.info("SecItemDelete(key) result= \(status)")
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
                    Logger.clientCert.info("SecItemDelete(certChain) \(summary) result = \(status)")
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

    @MainActor
    public func startImportClientCertificate(url: URL) async -> Bool {
        do {
            // Import PKCS12 client cert
            importingRawCert = try Data(contentsOf: url)

            guard let delegate else { return false }

            let shouldImport = await delegate.askForClientCertificateImport(self)
            return shouldImport
        } catch {
            Logger.clientCert.error("Failed to read certificate from URL: \(error.localizedDescription)")
            return false
        }
    }

    @MainActor
    public func clientCertificateAccepted(password: String?) async {
        importingPassword = password
        let status = decodePKCS12()

        switch status {
        case noErr:
            await addClientCertificateToKeychain()

        case errSecAuthFailed:
            guard let retryPassword = await delegate?.askForCertificatePassword(self) else {
                Logger.clientCert.warning("Password prompt cancelled after auth failure")
                return
            }
            await clientCertificateAccepted(password: retryPassword)

        default:
            let errMsg = String(format: String(localized: "unable_to_decode_certificate", comment: ""), "\(status)")
            await delegate?.alertClientCertificateError(self, errMsg: errMsg)
        }
    }

    public func clientCertificateRejected() {
        importingIdentity = nil
        importingRawCert = nil
        importingPassword = nil
    }

    @MainActor
    func addClientCertificateToKeychain() async {
        guard let identity = importingIdentity else {
            Logger.clientCert.error("No identity available to import")
            return
        }

        var clientCert: SecCertificate?
        var clientKey: SecKey?
        SecIdentityCopyCertificate(identity, &clientCert)
        SecIdentityCopyPrivateKey(identity, &clientKey)

        guard let cert = clientCert, let key = clientKey else {
            Logger.clientCert.error("Failed to extract cert or key from identity")
            return
        }

        let certAddQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: cert
        ]

        var status = SecItemAdd(certAddQuery as CFDictionary, nil)
        Logger.clientCert.info("SecItemAdd(cert) result=\(status)")

        if status == errSecDuplicateItem {
            Logger.clientCert.warning("Certificate already exists in Keychain")
            status = noErr // Treat as success, do not trigger error path later
        }

        if status == errSecSuccess {
            let keyAddQuery: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrIsPermanent as String: true,
                kSecValueRef as String: key
            ]

            status = SecItemAdd(keyAddQuery as CFDictionary, nil)
            Logger.clientCert.info("SecItemAdd(key) result=\(status)")

            if let certChain = importingCertChain {
                for chainCert in certChain where chainCert != cert {
                    let chainCertQuery: [String: Any] = [
                        kSecClass as String: kSecClassCertificate,
                        kSecValueRef as String: chainCert
                    ]
                    let chainStatus = SecItemAdd(chainCertQuery as CFDictionary, nil)
                    Logger.clientCert.info("SecItemAdd(certChain) result=\(chainStatus)")

                    if chainStatus == errSecDuplicateItem {
                        Logger.clientCert.info("Cert chain item already exists; skipping")

                        continue // Ignore duplicates
                    } else if chainStatus != errSecSuccess {
                        status = chainStatus
                        break
                    }
                }
            }
        }

        // Refresh the list of client identities
        loadFromKeychain()

        if status != errSecSuccess {
            _ = deleteFromKeychain(identity)

            var errorMessage = String(format: String(localized: "unable_to_add_certificate", comment: ""), "\(status)")
            if status == errSecDuplicateItem {
                errorMessage = String(localized: "certficate_exists", comment: "")
            }

            await delegate?.alertClientCertificateError(self, errMsg: errorMessage)
        }
    }

    public func decodePKCS12() -> OSStatus {
        // Import PKCS12 client cert
        var importResult: CFArray?
        guard let importingRawCert else {
            Logger.clientCert.error("No raw cert data to decode")
            return errSecParam
        }
        let status = SecPKCS12Import(importingRawCert as CFData, [kSecImportExportPassphrase as String: importingPassword ?? ""] as NSDictionary, &importResult)

        if status == noErr {
            // Extract the certifcate and private key
            let identityDictionaries = importResult as! [[String: Any]]
            importingIdentity = identityDictionaries[0][kSecImportItemIdentity as String] as! SecIdentity?
            importingCertChain = identityDictionaries[0][kSecImportItemCertChain as String] as! [SecCertificate]?
        } else {
            Logger.clientCert.info("SecPKCS12Import failed; result = \(status)")
        }
        return status
    }

    func evaluateTrust(with challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard let dns = challenge.protectionSpace.distinguishedNames,
              let identity = evaluateTrust(distinguishedNames: dns) else {
            return (.cancelAuthenticationChallenge, nil)
        }

        var cert: SecCertificate?
        SecIdentityCopyCertificate(identity, &cert)

        guard let cert else {
            Logger.clientCert.error("Failed to extract certificate from identity")
            return (.cancelAuthenticationChallenge, nil)
        }

        let certChain = buildIdentityCertChain(cert: cert)
        let credential = URLCredential(identity: identity, certificates: certChain, persistence: .forSession)
        return (.useCredential, credential)
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
        var trustError: CFError?
        if SecTrustEvaluateWithError(trust, &trustError) != true {
            SecTrustGetTrustResult(trust, &trustResult)
        }

        let chainSize = SecTrustGetCertificateCount(trust)

        if trustResult == .recoverableTrustFailure, chainSize > 1,
           let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate] {
            let rootCA = certificates[chainSize - 1]
            let anchors = [rootCA]
            Logger.clientCert.info("Setting anchor for trust evaluation to \(SecCertificateCopySubjectSummary(rootCA)! as String)")
            SecTrustSetAnchorCertificates(trust, anchors as CFArray)
            trustResult = SecTrustResultType.proceed
            var trustError: CFError?
            if SecTrustEvaluateWithError(trust, &trustError) != true {
                Logger.clientCert.info("Trust evaluation failed building client certificate chain after anchor has been set: \(trustError.debugDescription)")
                SecTrustGetTrustResult(trust, &trustResult)
            }
        }
        if trustResult != .proceed {
            return nil
        }

        let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate]
        return certificates?.filter { $0 != cert }
    }
}
