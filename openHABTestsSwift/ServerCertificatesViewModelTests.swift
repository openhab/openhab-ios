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
import Observation
@testable import openHAB
import OpenHABCore
import Testing

@Suite("ServerCertificatesViewModel")
@MainActor
struct ServerCertificatesViewModelTests {
    @Test("Loads certificates from the store sorted by domain")
    func loadsSortedByDomain() async {
        let store = await makeStore(domains: ["zeta.example.org", "alpha.example.org", "mid.example.org"])
        let viewModel = ServerCertificatesViewModel(store: store)

        await viewModel.loadCertificates()

        #expect(viewModel.certificates.map(\.domain) == ["alpha.example.org", "mid.example.org", "zeta.example.org"])
        // The fixture data is not a DER certificate, so there is no subject summary.
        #expect(viewModel.certificates.allSatisfy { $0.summary == nil })
    }

    @Test("Deleting removes the certificates from the store and the list")
    func deleteRemovesFromStoreAndList() async {
        let store = await makeStore(domains: ["a.example.org", "b.example.org", "c.example.org"])
        let viewModel = ServerCertificatesViewModel(store: store)
        await viewModel.loadCertificates()

        await viewModel.deleteCertificates(at: IndexSet([0, 2]))

        #expect(viewModel.certificates.map(\.domain) == ["b.example.org"])
        #expect(await store.getAllCertificates().keys.sorted() == ["b.example.org"])
    }

    @Test("Loading notifies observers of certificates")
    func loadingNotifiesObservers() async {
        let viewModel = await ServerCertificatesViewModel(store: makeStore(domains: ["a.example.org"]))
        let didChange = ObservationFlag()
        withObservationTracking {
            _ = viewModel.certificates
        } onChange: {
            didChange.set()
        }

        await viewModel.loadCertificates()

        #expect(didChange.value)
    }

    private func makeStore(domains: [String]) async -> CertificateStore {
        let store = CertificateStore(persistencePath: nil)
        for domain in domains {
            await store.storeCertificateData(Data(domain.utf8), forDomain: domain)
        }
        return store
    }
}
