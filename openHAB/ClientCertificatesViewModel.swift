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

import Combine
import OpenHABCore
import os.log
import SwiftUI

class ClientCertificatesViewModel: ObservableObject {
    @Published var clientCertificates: [SecIdentity] = []

    @MainActor func loadCertificates() {
        clientCertificates = CertificateManagers.clientCertificateManager.clientIdentities
    }

    @MainActor func deleteCertificate(at index: Int) {
        let status = CertificateManagers.clientCertificateManager.deleteFromKeychain(index: index)
        if status == noErr {
            clientCertificates.remove(at: index)
        }
    }

    @MainActor func getIdentityName(for index: Int) -> String {
        CertificateManagers.clientCertificateManager.getIdentityName(index: index)
    }
}
