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

@testable import openHAB
import OpenHABCore
import Testing

@Suite("ClientCertificatesViewModel")
@MainActor
struct ClientCertificatesViewModelTests {
    @Test("Loading mirrors the client certificate manager's identities")
    func loadingMirrorsManager() {
        let viewModel = ClientCertificatesViewModel()

        viewModel.loadCertificates()

        #expect(viewModel.clientCertificates == CertificateManagers.clientCertificateManager.clientIdentities)
    }
}
