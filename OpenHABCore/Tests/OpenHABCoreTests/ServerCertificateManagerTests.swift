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
@preconcurrency import Security
import Testing

final class MockServerCertificateDelegate: ServerCertificateManagerDelegate, @unchecked Sendable {
    nonisolated(unsafe) var lastCall = ""
    nonisolated(unsafe) var expectedResult: ServerCertificateManager.EvaluateResult = .permitOnce
    nonisolated(unsafe) var acceptedChangedCalled = false

    // swiftlint:disable:next async_without_await
    nonisolated func evaluateServerTrust(summary: String?, forDomain domain: String?) async -> ServerCertificateManager.EvaluateResult {
        lastCall = "evaluateServerTrust"
        return expectedResult
    }

    // swiftlint:disable:next async_without_await
    nonisolated func evaluateCertificateMismatch(summary: String?, forDomain domain: String?) async -> ServerCertificateManager.EvaluateResult {
        lastCall = "evaluateCertificateMismatch"
        return expectedResult
    }

    // swiftlint:disable:next async_without_await
    nonisolated func acceptedServerCertificatesChanged() async {
        acceptedChangedCalled = true
    }
}

// Create a X.509 certificate in DER format as test-cert.cer
// openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=TestCert"
// openssl x509 -outform der -in cert.pem -out test-cert.cer

@MainActor
@Suite("ServerCertificateManager Tests")
struct ServerCertificateManagerTests {
    func createTestContext() -> (manager: ServerCertificateManager, delegate: MockServerCertificateDelegate) {
        let delegate = MockServerCertificateDelegate()
        let manager = ServerCertificateManager()
        manager.delegate = delegate
        return (manager, delegate)
    }

    // Clear all certificates before each test to ensure isolation
    func clearCertificateStore() async {
        let store = CertificateManagers.certificateStore
        let allCerts = await store.getAllCertificates()
        for domain in allCerts.keys {
            await store.removeCertificate(forDomain: domain)
        }
    }

    @Test("SSL checking is ignored when configured")
    func ignoresSSLIfConfigured() async throws {
        await clearCertificateStore()

        let (manager, _) = createTestContext()
        manager.ignoreSSL = true
        let trust = try dummyTrust()

        try await manager.evaluate(trust, forHost: "ssl-ignore-test.openhab.org")
    }

    @Test("Previously stored certificate is accepted")
    func acceptsPreviouslyStoredCertificate() async throws {
        await clearCertificateStore()

        let (manager, _) = createTestContext()
        let trust = try dummyTrust()
        let domain = "accepted-test.openhab.org" // Unique domain
        let cert = manager.getLeafCertificate(trust: trust)!
        let certData = SecCertificateCopyData(cert) as Data

        // Store certificate in the shared store
        await CertificateManagers.certificateStore.storeCertificateData(certData, forDomain: domain)

        try await manager.evaluate(trust, forHost: domain)
    }

    @Test("Certificate mismatch triggers delegate")
    func triggersMismatchDelegateWhenCertsDiffer() async throws {
        await clearCertificateStore()

        let (manager, delegate) = createTestContext()
        let trust = try dummyTrust()
        let domain = "mismatch-test.openhab.org" // Unique domain

        // Store different fake cert data
        await CertificateManagers.certificateStore.storeCertificateData(Data([0x01, 0x02]), forDomain: domain)

        delegate.expectedResult = .permitOnce
        try await manager.evaluate(trust, forHost: domain)

        #expect(delegate.lastCall == "evaluateCertificateMismatch")
    }

    @Test("Server trust delegate is triggered for new certificate")
    func triggersServerTrustDelegateForNewCert() async throws {
        await clearCertificateStore()

        let (manager, delegate) = createTestContext()
        let trust = try dummyTrust()
        let domain = "new-cert-test.openhab.org" // Unique domain

        delegate.expectedResult = .permitOnce
        try await manager.evaluate(trust, forHost: domain)

        #expect(delegate.lastCall == "evaluateServerTrust")
    }

    @Test("Error is thrown when user denies trust")
    func throwsWhenUserDeniesTrust() async throws {
        await clearCertificateStore()

        let (manager, delegate) = createTestContext()
        let trust = try dummyTrust()
        let domain = "deny-test.openhab.org" // Unique domain

        // Ensure no certificate is stored for this domain
        await CertificateManagers.certificateStore.removeCertificate(forDomain: domain)
        let storedData = await CertificateManagers.certificateStore.certificateData(forDomain: domain)
        #expect(storedData == nil) // Sanity check

        delegate.expectedResult = .deny

        await #expect(throws: (any Error).self) {
            try await manager.evaluate(trust, forHost: domain)
        }
    }

    @Test("Certificate is stored when user accepts always")
    func storesCertWhenUserAcceptsAlways() async throws {
        await clearCertificateStore()

        let (manager, delegate) = createTestContext()
        let trust = try dummyTrust()
        let domain = "persist-test.openhab.org" // Unique domain

        // Ensure no certificate is stored initially
        await CertificateManagers.certificateStore.removeCertificate(forDomain: domain)
        let initialData = await CertificateManagers.certificateStore.certificateData(forDomain: domain)
        #expect(initialData == nil) // Sanity check

        delegate.expectedResult = .permitAlways
        try await manager.evaluate(trust, forHost: domain)

        let storedData = await CertificateManagers.certificateStore.certificateData(forDomain: domain)
        #expect(storedData != nil)
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
