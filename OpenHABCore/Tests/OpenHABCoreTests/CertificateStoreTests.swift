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

@Suite("CertificateStore Tests", .serialized)
struct CertificateStoreTests {
    // Helper to load the bundled test certificate data
    func loadTestCertificateData() throws -> Data {
        let certURL = Bundle.module.url(forResource: "test-cert", withExtension: "cer")!
        return try Data(contentsOf: certURL)
    }

    // Helper to create a fresh store (actor) instance
    func makeStore() -> CertificateStore {
        CertificateStore.shared
    }

    @Test("Store and retrieve certificate")
    func storeAndRetrieve() async throws {
        let domain = "store-retrieve-test.openhab.org"
        let store = makeStore()

        let data = try loadTestCertificateData()
        await store.storeCertificateData(data, forDomain: domain)
        let fetched = await store.certificateData(forDomain: domain)

        #expect(fetched == data)

        // Also validate getCertificateInfo returns entry with data and a recent date
        let info = await store.getCertificateInfo(forDomain: domain)
        #expect(info != nil)
        #expect(info?.data == data)
        #expect(info!.dateAccepted.timeIntervalSinceNow > -5) // stored just now

        await store.removeCertificate(forDomain: domain)
    }

    @Test("Overwrite existing certificate updates data and date")
    func overwriteUpdates() async throws {
        let domain = "overwrite-test.openhab.org"
        let store = makeStore()

        let first = Data([0x01, 0x02, 0x03])
        await store.storeCertificateData(first, forDomain: domain)
        let firstInfo = await store.getCertificateInfo(forDomain: domain)
        #expect(firstInfo != nil)
        let firstDate = firstInfo!.dateAccepted

        // Overwrite with new data
        let second = Data([0x0A, 0x0B])
        await store.storeCertificateData(second, forDomain: domain)

        let info = await store.getCertificateInfo(forDomain: domain)
        #expect(info != nil)
        #expect(info!.data == second)
        #expect(info!.dateAccepted >= firstDate)

        await store.removeCertificate(forDomain: domain)
    }

    @Test("Remove certificate clears entry")
    func removeClears() async throws {
        let domain = "remove-test.openhab.org"
        let store = makeStore()

        let data = Data([0xAA, 0xBB])
        await store.storeCertificateData(data, forDomain: domain)
        #expect(await store.certificateData(forDomain: domain) != nil)

        await store.removeCertificate(forDomain: domain)
        let fetched = await store.certificateData(forDomain: domain)
        #expect(fetched == nil)
        let info = await store.getCertificateInfo(forDomain: domain)
        #expect(info == nil)
    }

    @Test("Store nil removes certificate")
    func storeNilRemoves() async throws {
        let domain = "nil-remove-test.openhab.org"
        let store = makeStore()

        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
        await store.storeCertificateData(data, forDomain: domain)
        #expect(await store.certificateData(forDomain: domain) == data)

        await store.storeCertificateData(nil, forDomain: domain)
        #expect(await store.certificateData(forDomain: domain) == nil)

        await store.removeCertificate(forDomain: domain)
    }

    @Test("Get all certificates returns expected entries")
    func getAllCertificates() async throws {
        let domainA = "list-a-test.openhab.org"
        let domainB = "list-b-test.openhab.org"
        let store = makeStore()

        let dataA = Data([0x01])
        let dataB = Data([0x02])
        await store.storeCertificateData(dataA, forDomain: domainA)
        await store.storeCertificateData(dataB, forDomain: domainB)

        let all = await store.getAllCertificates()
        #expect(all[domainA]?.data == dataA)
        #expect(all[domainB]?.data == dataB)
        #expect(all.keys.contains(domainA))
        #expect(all.keys.contains(domainB))

        await store.removeCertificate(forDomain: domainA)
        await store.removeCertificate(forDomain: domainB)
    }

    @Test("Persistence across instances")
    func persistenceAcrossInstances() async throws {
        let domain = "persistence-test.openhab.org"
        var store: CertificateStore? = makeStore()

        Logger.defaultLoggingMiddleware.log("Running persistenceAcrossInstances")
        let data = Data([0xFE, 0xED, 0xFA, 0xCE])
        await store!.storeCertificateData(data, forDomain: domain)

        // Ensure the store is completely finished with file operations
        // by setting it to nil and waiting a moment
        store = nil

        // Create a new instance which should load from disk
        store = makeStore()
        let fetched = await store!.certificateData(forDomain: domain)
        #expect(fetched == data, "Certificate data should persist across instances")

        await store?.removeCertificate(forDomain: domain)
    }
}
