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
import os.log
import Testing

// MARK: - Test Errors

enum CertificateStoreTestError: Error {
    case resourceNotFound(String)
}

@Suite("CertificateStore Tests", .serialized)
struct CertificateStoreTests {
    /// Helper to load the bundled test certificate data
    func loadTestCertificateData() throws -> Data {
        guard let certURL = Bundle.module.url(forResource: "test-cert", withExtension: "cer") else {
            throw CertificateStoreTestError.resourceNotFound("test-cert.cer")
        }
        return try Data(contentsOf: certURL)
    }

    /// Helper to create a fresh in-memory store for isolated testing
    func makeInMemoryStore() -> CertificateStore {
        CertificateStore(persistencePath: nil)
    }

    /// Helper to create a unique temporary path for persistence tests
    func makeTempPersistencePath() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let uniqueID = UUID().uuidString
        return tempDir.appendingPathComponent("CertificateStoreTests-\(uniqueID)")
    }

    @Test("Store and retrieve certificate", .timeLimit(.minutes(1)))
    func storeAndRetrieve() async throws {
        let domain = "store-retrieve-test.openhab.org"
        let store = makeInMemoryStore()

        let data = try loadTestCertificateData()
        await store.storeCertificateData(data, forDomain: domain)
        let fetched = await store.certificateData(forDomain: domain)

        #expect(fetched == data)

        // Also validate getCertificateInfo returns entry with data and a recent date
        let info = await store.getCertificateInfo(forDomain: domain)
        #expect(info != nil)
        #expect(info?.data == data)
        #expect(try #require(info?.dateAccepted.timeIntervalSinceNow) > -5) // stored just now
    }

    @Test("Overwrite existing certificate updates data and date", .timeLimit(.minutes(1)))
    func overwriteUpdates() async throws {
        let domain = "overwrite-test.openhab.org"
        let store = makeInMemoryStore()

        let first = Data([0x01, 0x02, 0x03])
        await store.storeCertificateData(first, forDomain: domain)
        let firstInfo = await store.getCertificateInfo(forDomain: domain)
        #expect(firstInfo != nil)
        let firstDate = try #require(firstInfo?.dateAccepted)

        // Overwrite with new data
        let second = Data([0x0A, 0x0B])
        await store.storeCertificateData(second, forDomain: domain)

        let info = await store.getCertificateInfo(forDomain: domain)
        #expect(info != nil)
        #expect(info?.data == second)
        #expect(try #require(info?.dateAccepted) >= firstDate)
    }

    @Test("Remove certificate clears entry", .timeLimit(.minutes(1)))
    func removeClears() async {
        let domain = "remove-test.openhab.org"
        let store = makeInMemoryStore()

        let data = Data([0xAA, 0xBB])
        await store.storeCertificateData(data, forDomain: domain)
        #expect(await store.certificateData(forDomain: domain) != nil)

        await store.removeCertificate(forDomain: domain)
        let fetched = await store.certificateData(forDomain: domain)
        #expect(fetched == nil)
        let info = await store.getCertificateInfo(forDomain: domain)
        #expect(info == nil)
    }

    @Test("Store nil removes certificate", .timeLimit(.minutes(1)))
    func storeNilRemoves() async {
        let domain = "nil-remove-test.openhab.org"
        let store = makeInMemoryStore()

        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
        await store.storeCertificateData(data, forDomain: domain)
        #expect(await store.certificateData(forDomain: domain) == data)

        await store.storeCertificateData(nil, forDomain: domain)
        #expect(await store.certificateData(forDomain: domain) == nil)
    }

    @Test("Get all certificates returns expected entries", .timeLimit(.minutes(1)))
    func getAllCertificates() async {
        let domainA = "list-a-test.openhab.org"
        let domainB = "list-b-test.openhab.org"
        let store = makeInMemoryStore()

        let dataA = Data([0x01])
        let dataB = Data([0x02])
        await store.storeCertificateData(dataA, forDomain: domainA)
        await store.storeCertificateData(dataB, forDomain: domainB)

        let all = await store.getAllCertificates()
        #expect(all[domainA]?.data == dataA)
        #expect(all[domainB]?.data == dataB)
        #expect(all.keys.contains(domainA))
        #expect(all.keys.contains(domainB))
    }

    @Test("Persistence across instances", .timeLimit(.minutes(1)))
    func persistenceAcrossInstances() async {
        let domain = "persistence-test.openhab.org"
        let tempPath = makeTempPersistencePath()

        // Clean up any existing file
        try? FileManager.default.removeItem(at: tempPath)

        do {
            // Create first store instance with temp path
            let store1 = CertificateStore(persistencePath: tempPath)

            Logger.defaultLoggingMiddleware.log("Running persistenceAcrossInstances")
            let data = Data([0xFE, 0xED, 0xFA, 0xCE])
            await store1.storeCertificateData(data, forDomain: domain)

            // Create a new instance which should load from disk
            let store2 = CertificateStore(persistencePath: tempPath)
            let fetched = await store2.certificateData(forDomain: domain)
            #expect(fetched == data, "Certificate data should persist across instances")
        }

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempPath)
    }
}
