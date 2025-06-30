// Copyright (c) 2010-2025 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

@testable import OpenHABCore
import XCTest

@MainActor
func XCTAssertThrowsErrorAsync(
    _ expression: @escaping () async throws -> some Any,
    _ message: @autoclosure () -> String = "Expected async error but got success",
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail(message(), file: file, line: line)
    } catch {
        // ✅ Success – an error was thrown
    }
}

final class MockServerCertificateDelegate: ServerCertificateManagerDelegate {
    var lastCall = ""
    var expectedResult: ServerCertificateManager.EvaluateResult = .permitOnce
    var acceptedChangedCalled = false

    func evaluateServerTrust(summary: String?, forDomain domain: String?) async -> ServerCertificateManager.EvaluateResult {
        lastCall = "evaluateServerTrust"
        return expectedResult
    }

    func evaluateCertificateMismatch(summary: String?, forDomain domain: String?) async -> ServerCertificateManager.EvaluateResult {
        lastCall = "evaluateCertificateMismatch"
        return expectedResult
    }

    func acceptedServerCertificatesChanged() {
        acceptedChangedCalled = true
    }
}

// Create a X.509 certificate in DER format as test-cert.cer
// openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=TestCert"
// openssl x509 -outform der -in cert.pem -out test-cert.cer

final class ServerCertificateManagerTests: XCTestCase {
    var manager: ServerCertificateManager!
    var delegate: MockServerCertificateDelegate!

    override func setUp() {
        super.setUp()
        delegate = MockServerCertificateDelegate()
        manager = ServerCertificateManager()
        manager.delegate = delegate
    }

    override func tearDown() {
        manager = nil
        delegate = nil
        super.tearDown()
    }

    func testIgnoresSSLIfConfigured() async throws {
        manager.ignoreSSL = true
        let trust = try dummyTrust()

        do {
            try await manager.evaluate(trust, forHost: "test.openhab.org")
        } catch {
            XCTFail("Expected no error, but got: \(error)")
        }
    }

    func testAcceptsPreviouslyStoredCertificate() async throws {
        let trust = try dummyTrust()
        let domain = "test.openhab.org"
        let cert = manager.getLeafCertificate(trust: trust)!
        let certData = SecCertificateCopyData(cert) as Data
        manager.trustedCertificates[domain] = certData

        do {
            try await manager.evaluate(trust, forHost: domain)
        } catch {
            XCTFail("Expected no error, but got: \(error)")
        }
    }

    @MainActor
    func testTriggersMismatchDelegateWhenCertsDiffer() async throws {
        let trust = try dummyTrust()
        let domain = "test.openhab.org"
        manager.trustedCertificates[domain] = Data([0x01, 0x02]) // fake cert

        delegate.expectedResult = .permitOnce
        try await manager.evaluate(trust, forHost: domain)

        XCTAssertEqual(delegate.lastCall, "evaluateCertificateMismatch")
    }

    @MainActor
    func testTriggersServerTrustDelegateForNewCert() async throws {
        let trust = try dummyTrust()
        let domain = "unknown.openhab.org"

        delegate.expectedResult = .permitOnce
        try await manager.evaluate(trust, forHost: domain)

        XCTAssertEqual(delegate.lastCall, "evaluateServerTrust")
    }

    @MainActor
    func testThrowsWhenUserDeniesTrust() async throws {
        let trust = try dummyTrust()
        let domain = "deny.openhab.org"

        manager.trustedCertificates.removeAll()
        XCTAssertNil(manager.trustedCertificates[domain]) // Sanity check

        delegate.expectedResult = .deny

        await XCTAssertThrowsErrorAsync {
            try await self.manager.evaluate(trust, forHost: domain)
        }
    }

    @MainActor
    func testStoresCertWhenUserAcceptsAlways() async throws {
        let trust = try dummyTrust()
        let domain = "persist.openhab.org"

        manager.trustedCertificates.removeAll()
        XCTAssertNil(manager.trustedCertificates[domain]) // Sanity check

        delegate.expectedResult = .permitAlways
        try await manager.evaluate(trust, forHost: domain)

        XCTAssertNotNil(manager.trustedCertificates[domain])
        XCTAssertTrue(delegate.acceptedChangedCalled, "Delegate should be notified when cert is stored")
    }

    // MARK: - Helper

    func dummyTrust() throws -> SecTrust {
        let certPath = Bundle.module.url(forResource: "test-cert", withExtension: "cer")!
        let certData = try Data(contentsOf: certPath)
        let cert = SecCertificateCreateWithData(nil, certData as CFData)!
        let policy = SecPolicyCreateSSL(true, nil)

        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(cert, policy, &trust)
        guard status == errSecSuccess else { throw NSError(domain: "TrustCreate", code: Int(status)) }
        return trust!
    }
}
