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

import Observation
import OpenHABCore
import Security

@MainActor
@Observable
final class ClientCertificatesViewModel {
    var clientCertificates: [SecIdentity] = []

    func loadCertificates() {
        clientCertificates = CertificateManagers.clientCertificateManager.clientIdentities
    }

    func deleteCertificate(at index: Int) {
        let status = CertificateManagers.clientCertificateManager.deleteFromKeychain(index: index)
        if status == noErr {
            clientCertificates.remove(at: index)
        }
    }

    func getIdentityName(for index: Int) -> String {
        CertificateManagers.clientCertificateManager.getIdentityName(index: index)
    }
}
