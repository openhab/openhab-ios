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
import os.log
import Security
import SwiftUI

@MainActor
@Observable
final class ServerCertificatesViewModel {
    struct CertificateInfo {
        let domain: String
        let summary: String?
        let dateAdded: Date
    }

    var certificates: [CertificateInfo] = []

    private let store: CertificateStore

    init(store: CertificateStore = CertificateManagers.certificateStore) {
        self.store = store
    }

    func loadCertificates() async {
        Logger.serverCert.info("Loading certificates")
        let trustedCertificates = await store.getAllCertificates()
        certificates = trustedCertificates.map { domain, certificateEntry in
            let certificate = SecCertificateCreateWithData(nil, certificateEntry.data as CFData)
            let summary = certificate.map { SecCertificateCopySubjectSummary($0) as String? } ?? nil
            return CertificateInfo(domain: domain, summary: summary, dateAdded: certificateEntry.dateAccepted)
        }
        .sorted { $0.domain < $1.domain }
    }

    func deleteCertificates(at offsets: IndexSet) async {
        let domains = offsets.map { certificates[$0].domain }
        for domain in domains {
            await store.removeCertificate(forDomain: domain)
        }
        await loadCertificates()
    }
}

struct ServerCertificatesView: View {
    @State private var viewModel = ServerCertificatesViewModel()

    var body: some View {
        List {
            if viewModel.certificates.isEmpty {
                Text("No accepted server certificates")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.certificates, id: \.domain) { certificate in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(certificate.domain)
                            .font(.headline)
                        if let summary = certificate.summary {
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Added: \(certificate.dateAdded, format: .dateTime.year().month().day().hour().minute())")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .onDelete(perform: deleteCertificates)
            }
        }
        .navigationTitle("Accepted Server Certificates")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadCertificates()
        }
    }

    private func deleteCertificates(offsets: IndexSet) {
        Task { await viewModel.deleteCertificates(at: offsets) }
    }
}

#Preview {
    NavigationStack {
        ServerCertificatesView()
    }
}
