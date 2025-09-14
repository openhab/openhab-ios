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

import Foundation
@testable import OpenHABCore
@preconcurrency import Security
import Testing

final class MockServerCertificateDelegate: ServerCertificateManagerDelegate, @unchecked Sendable {
    nonisolated(unsafe) var lastCall = ""
    nonisolated(unsafe) var expectedResult: ServerCertificateManager.EvaluateResult = .permitOnce
    nonisolated(unsafe) var acceptedChangedCalled = false

    nonisolated func evaluateServerTrust(summary: String?, forDomain domain: String?) async -> ServerCertificateManager.EvaluateResult {
        lastCall = "evaluateServerTrust"
        return expectedResult
    }

    nonisolated func evaluateCertificateMismatch(summary: String?, forDomain domain: String?) async -> ServerCertificateManager.EvaluateResult {
        lastCall = "evaluateCertificateMismatch"
        return expectedResult
    }

    nonisolated func acceptedServerCertificatesChanged() {
        acceptedChangedCalled = true
    }
}

// Create a X.509 certificate in DER format as test-cert.cer
// openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=TestCert"
// openssl x509 -outform der -in cert.pem -out test-cert.cer

@Suite("ServerCertificateManager Tests")
struct ServerCertificateManagerTests {
    init() {}

    func createTestContext() -> (manager: ServerCertificateManager, delegate: MockServerCertificateDelegate) {
        let delegate = MockServerCertificateDelegate()
        let manager = ServerCertificateManager()
        manager.delegate = delegate
        return (manager, delegate)
    }

    @Test("SSL checking is ignored when configured")
    func ignoresSSLIfConfigured() async throws {
        let (manager, _) = createTestContext()
        manager.ignoreSSL = true
        let trust = try dummyTrust()

        try await manager.evaluate(trust, forHost: "test.openhab.org")
    }

    @Test("Previously stored certificate is accepted")
    func acceptsPreviouslyStoredCertificate() async throws {
        let (manager, _) = createTestContext()
        let trust = try dummyTrust()
        let domain = "test.openhab.org"
        let cert = manager.getLeafCertificate(trust: trust)!
        let certData = SecCertificateCopyData(cert) as Data
        manager.trustedCertificates[domain] = certData

        try await manager.evaluate(trust, forHost: domain)
    }

    @Test("Certificate mismatch triggers delegate")
    func triggersMismatchDelegateWhenCertsDiffer() async throws {
        let (manager, delegate) = createTestContext()
        let trust = try dummyTrust()
        let domain = "test.openhab.org"
        manager.trustedCertificates[domain] = Data([0x01, 0x02]) // fake cert

        delegate.expectedResult = .permitOnce
        try await manager.evaluate(trust, forHost: domain)

        #expect(delegate.lastCall == "evaluateCertificateMismatch")
    }

    @Test("Server trust delegate is triggered for new certificate")
    func triggersServerTrustDelegateForNewCert() async throws {
        let (manager, delegate) = createTestContext()
        let trust = try dummyTrust()
        let domain = "unknown.openhab.org"

        delegate.expectedResult = .permitOnce
        try await manager.evaluate(trust, forHost: domain)

        #expect(delegate.lastCall == "evaluateServerTrust")
    }

    @Test("Error is thrown when user denies trust")
    func throwsWhenUserDeniesTrust() async throws {
        let (manager, delegate) = createTestContext()
        let trust = try dummyTrust()
        let domain = "deny.openhab.org"

        manager.trustedCertificates.removeAll()
        #expect(manager.trustedCertificates[domain] == nil) // Sanity check

        delegate.expectedResult = .deny

        await #expect(throws: (any Error).self) {
            try await manager.evaluate(trust, forHost: domain)
        }
    }

    @Test("Certificate is stored when user accepts always")
    func storesCertWhenUserAcceptsAlways() async throws {
        let (manager, delegate) = createTestContext()
        let trust = try dummyTrust()
        let domain = "persist.openhab.org"

        manager.trustedCertificates.removeAll()
        #expect(manager.trustedCertificates[domain] == nil) // Sanity check

        delegate.expectedResult = .permitAlways
        try await manager.evaluate(trust, forHost: domain)

        #expect(manager.trustedCertificates[domain] != nil)
        #expect(delegate.acceptedChangedCalled == true, "Delegate should be notified when cert is stored")
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
