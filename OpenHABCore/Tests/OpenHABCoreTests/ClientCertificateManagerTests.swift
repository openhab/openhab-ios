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
@testable import OpenHABCore
import Testing

final class MockClientCertDelegate: ClientCertificateManagerDelegate {
    var shouldImport = true
    var password: String? = "test1234"
    var receivedErrorMessage: String?
    var receivedErrorCode: OSStatus?

    func askForClientCertificateImport(_ clientCertificateManager: ClientCertificateManager?) -> Bool {
        shouldImport
    }

    func askForCertificatePassword(_ clientCertificateManager: ClientCertificateManager?) -> String? {
        password
    }

    func alertClientCertificateError(_ clientCertificateManager: ClientCertificateManager?, errMsg: String) {
        receivedErrorMessage = errMsg
        if let code = Int(errMsg.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
            receivedErrorCode = OSStatus(code)
        }
    }
}

// MARK: Instructions

// To create test.p12
// openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=TestCert"
// openssl pkcs12 -export -out test.p12 -inkey key.pem -in cert.pem -password pass:password

struct ClientCertificateManagerTests {
    let manager: ClientCertificateManager
    let delegate: MockClientCertDelegate

    init() {
        manager = ClientCertificateManager()
        delegate = MockClientCertDelegate()
        manager.delegate = delegate
    }

    @Test func startImportCertificateReturnsFalseIfDataMissing() async {
        let result = await manager.startImportClientCertificate(url: URL(fileURLWithPath: "/nonexistent.p12"))
        #expect(!result)
    }

    @Test func startImportCertificateReturnsTrueIfDelegateApproves() async throws {
        guard let url = Bundle.module.url(forResource: "test", withExtension: "p12") else {
            Issue.record("Test PKCS#12 file not found.")
            return
        }

        let result = await manager.startImportClientCertificate(url: url)
        #expect(result)
    }

    @Test func pKCS12DecodeReturnsIdentity() {
        manager.importingRawCert = loadMockPKCS12Data()
        manager.importingPassword = "password"

        let status = manager.decodePKCS12()
        #expect(status == errSecSuccess)
        #expect(manager.importingIdentity != nil)
    }

    @Test @MainActor func clientCertificateAcceptedFailsAndAlerts() async {
        manager.importingRawCert = Data([0x00, 0x01, 0x02]) // invalid cert
        await manager.clientCertificateAccepted(password: "badpassword")
        #expect(delegate.receivedErrorMessage != nil)
    }

    private func loadMockPKCS12Data() -> Data? {
        guard let url = Bundle.module.url(forResource: "test", withExtension: "p12") else { return nil }
        return try? Data(contentsOf: url)
    }
}
