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

protocol ClientCertificateManagerDelegate: NSObjectProtocol {
    // delegate should ask user for a decision on whether to import the client certificate into the keychain
    func askForClientCertificateImport(_ clientCertificateManager: ClientCertificateManager?)
    // delegate should ask user for the export password used to decode the PKCS#12
    func askForCertificatePassword(_ clientCertificateManager: ClientCertificateManager?)
    // delegate should alert the user that an error occured importing the certificate
    func alertClientCertificateError(_ clientCertificateManager: ClientCertificateManager?, errMsg: String)
}

class ClientCertificateManager {
    private var importingRawCert: Data?
    private var importingClientKey: SecKey?
    private var importingClientCert: SecCertificate?
    private var importingPassword: String?

    weak var delegate: ClientCertificateManagerDelegate?

    var clientIdentities: [SecIdentity] = []

    init() {
        loadFromKeychain()
    }

    func loadFromKeychain() {
        let getIdentityQuery: [String: Any] = [kSecClass as String: kSecClassIdentity,
                                               kSecReturnRef as String: true,
                                               kSecMatchLimit as String: kSecMatchLimitAll]
        var items: CFTypeRef?
        let status = SecItemCopyMatching(getIdentityQuery as CFDictionary, &items)
        if status == errSecSuccess {
            clientIdentities = items as! [SecIdentity]
        }
    }

    func getIdentityName(index: Int) -> String {
        if index >= 0, index < clientIdentities.count {
            let identity = clientIdentities[index]
            var cert: SecCertificate?
            SecIdentityCopyCertificate(identity, &cert)
            let subject = SecCertificateCopySubjectSummary(cert!)
            if subject != nil {
                return subject! as String
            }
        }
        return ""
    }

    func evaluateTrust(distinguishedNames: [Data]) -> SecIdentity? {
        // Search the keychain for an identity that matches the DN of the certificate being requested by the server
        let getIdentityQuery: [String: Any] = [kSecClass as String: kSecClassIdentity,
                                               kSecReturnRef as String: true,
                                               kSecMatchLimit as String: kSecMatchLimitOne,
                                               kSecMatchIssuers as String: distinguishedNames]
        var identity: CFTypeRef?
        let status = SecItemCopyMatching(getIdentityQuery as CFDictionary, &identity)
        if status == errSecSuccess {
            return (identity as! SecIdentity)
        }
        return nil
    }

    func addToKeychain(key: SecKey, cert: SecCertificate) -> OSStatus {
        // Add the certificate to the keychain
        let addCertQuery: [String: Any] = [kSecClass as String: kSecClassCertificate,
                                           kSecValueRef as String: cert]
        var status = SecItemAdd(addCertQuery as NSDictionary, nil)
        os_log("SecItemAdd(cert) result=%{PUBLIC}d", log: .default, type: .info, status)
        if status == noErr {
            let addKeyQuery: [String: Any] = [kSecClass as String: kSecClassKey,
                                              kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                                              kSecAttrIsPermanent as String: true,
                                              kSecValueRef as String: key]
            status = SecItemAdd(addKeyQuery as NSDictionary, nil)
            os_log("SecItemAdd(key) result=%{PUBLIC}d", log: .default, type: .info, status)
            if status == noErr {
                // Refresh identities from the keychain
                loadFromKeychain()
            } else {
                // Private key add failed so clean up the previously added cert
                let deleteCertQuery: [String: Any] = [kSecClass as String: kSecClassCertificate,
                                                      kSecValueRef as String: cert]
                let status = SecItemDelete(deleteCertQuery as NSDictionary)
                os_log("SecItemDelete(cert) result=%{PUBLIC}d", log: .default, type: .info, status)
            }
        }

        return status
    }

    func deleteFromKeychain(index: Int) -> OSStatus {
        let identity = clientIdentities[index]

        var cert: SecCertificate?
        SecIdentityCopyCertificate(identity, &cert)
        var key: SecKey?
        SecIdentityCopyPrivateKey(identity, &key)

        let deleteCertQuery: [String: Any] = [kSecClass as String: kSecClassCertificate,
                                              kSecValueRef as String: cert!]
        var status = SecItemDelete(deleteCertQuery as NSDictionary)
        os_log("SecItemDelete(cert) result=%{PUBLIC}d", log: .default, type: .info, status)
        if status == noErr {
            let deleteKeyQuery: [String: Any] = [kSecClass as String: kSecClassKey,
                                                 kSecValueRef as String: key!]
            status = SecItemDelete(deleteKeyQuery as NSDictionary)
            os_log("SecItemDelete(key) result=%{PUBLIC}d", log: .default, type: .info, status)
            clientIdentities.remove(at: index)
        }
        return status
    }

    func startImportClientCertificate(url: URL) -> Bool {
        do {
            // Import PKCS12 client cert
            importingRawCert = try Data(contentsOf: url)

            if delegate != nil {
                delegate!.askForClientCertificateImport(self)
            } else {
                return false
            }
        } catch {
            os_log("Unable to read certificate from URL", log: .default, type: .info)
            return false
        }
        return true
    }

    func clientCertificateAccepted(password: String?) {
        // Import PKCS12 client cert
        importingPassword = password
        let status = decodePKCS12()
        if status == noErr {
            addClientCertificateToKeychain()
        } else if status == errSecAuthFailed {
            if delegate != nil {
                delegate!.askForCertificatePassword(self)
            }
        } else {
            let errMsg = "Unable to decode certificate: \(status)."
            if delegate != nil {
                delegate!.alertClientCertificateError(self, errMsg: errMsg)
            }
        }
    }

    func clientCertificateRejected() {
        importingClientKey = nil
        importingClientCert = nil
        importingRawCert = nil
        importingPassword = nil
    }

    func addClientCertificateToKeychain() {
        let status = addToKeychain(key: importingClientKey!, cert: importingClientCert!)
        if status != noErr {
            var errMsg = "Unable to add certificate to the keychain: \(status)."
            if status == errSecDuplicateItem {
                errMsg = "Certificate already exists in the keychain."
            }
            if delegate != nil {
                delegate!.alertClientCertificateError(self, errMsg: errMsg)
            }
        }
    }

    private func decodePKCS12() -> OSStatus {
        // Import PKCS12 client cert
        var importResult: CFArray?
        let status = SecPKCS12Import(importingRawCert! as CFData, [kSecImportExportPassphrase as String: importingPassword ?? ""] as NSDictionary, &importResult)
        if status == noErr {
            // Extract the certifcate and private key
            let identityDictionaries = importResult as! [[String: Any]]
            let identity = identityDictionaries[0][kSecImportItemIdentity as String] as! SecIdentity
            SecIdentityCopyPrivateKey(identity, &importingClientKey)
            SecIdentityCopyCertificate(identity, &importingClientCert)
        } else {
            os_log("SecPKCS12Import failed; result=%{PUBLIC}d", log: .default, type: .info, status)
        }
        return status
    }

    func evaluateTrust(challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let dns = challenge.protectionSpace.distinguishedNames
        if let dns = dns {
            let identity = evaluateTrust(distinguishedNames: dns)
            if let identity = identity {
                let credential = URLCredential(identity: identity, certificates: nil, persistence: URLCredential.Persistence.forSession)
                return (.useCredential, credential)
            }
        }
        return (.cancelAuthenticationChallenge, nil)
    }
}
