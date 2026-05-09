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
import XCTest

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

final class ClientCertificateManagerTests: XCTestCase {
    var manager: ClientCertificateManager!
    var delegate: MockClientCertDelegate!

    override func setUp() {
        super.setUp()
        manager = ClientCertificateManager()
        delegate = MockClientCertDelegate()
        manager.delegate = delegate
    }

    override func tearDown() {
        manager = nil
        delegate = nil
        super.tearDown()
    }

    func testStartImportCertificateReturnsFalseIfDataMissing() async {
        let result = await manager.startImportClientCertificate(url: URL(fileURLWithPath: "/nonexistent.p12"))
        XCTAssertFalse(result)
    }

    func testStartImportCertificateReturnsTrueIfDelegateApproves() async throws {
        // Use a real P12 file in your test bundle if needed
        guard let url = Bundle.module.url(forResource: "test", withExtension: "p12") else {
            return XCTFail("Test PKCS#12 file not found.")
        }

        let result = await manager.startImportClientCertificate(url: url)
        XCTAssertTrue(result)
    }

//    func testClientCertificateAcceptedSuccessPath() async {
//        manager.importingRawCert = loadMockPKCS12Data()
//        delegate.password = "password"
//
//        await manager.clientCertificateAccepted(password: "password")
//        XCTAssertNil(delegate.receivedErrorMessage)
//    }

    func testPKCS12DecodeReturnsIdentity() {
        manager.importingRawCert = loadMockPKCS12Data()
        manager.importingPassword = "password"

        let status = manager.decodePKCS12()
        XCTAssertEqual(status, errSecSuccess)
        XCTAssertNotNil(manager.importingIdentity)
    }

//    func testClientCertificateAcceptedFailsAndAlerts() async {
//        manager.importingRawCert = Data([0x00, 0x01, 0x02]) // invalid cert
//        await manager.clientCertificateAccepted(password: "badpassword")
//        XCTAssertNotNil(delegate.receivedErrorMessage)
//    }

    @MainActor
    func testClientCertificateAcceptedFailsAndAlerts() async {
        manager.importingRawCert = Data([0x00, 0x01, 0x02]) // invalid cert
        await manager.clientCertificateAccepted(password: "badpassword")

        let errorMessage = await MainActor.run { delegate.receivedErrorMessage }
        XCTAssertNotNil(errorMessage)
    }

    // Helper to load valid PKCS#12 mock
    private func loadMockPKCS12Data() -> Data? {
        guard let url = Bundle.module.url(forResource: "test", withExtension: "p12") else { return nil }
        return try? Data(contentsOf: url)
    }
}
