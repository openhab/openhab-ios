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

import Combine
import OpenHABCore
import os.log
import Security
import SwiftUI

@MainActor
class ServerCertificatesViewModel: ObservableObject {
    struct CertificateInfo {
        let domain: String
        let summary: String?
        let dateAdded: Date
    }

    @Published var certificates: [CertificateInfo] = []

    func loadCertificates() {
        Task {
            Logger.serverCert.info("Loading certificates")
            let store = CertificateManagers.certificateStore
            var certInfos: [CertificateInfo] = []

            let trustedCertificates = await store.getAllCertificates()
            for (domain, certificateEntry) in trustedCertificates {
                let certificate = SecCertificateCreateWithData(nil, certificateEntry.data as CFData)
                let summary = certificate.map { SecCertificateCopySubjectSummary($0) as String? } ?? nil

                certInfos.append(CertificateInfo(
                    domain: domain,
                    summary: summary,
                    dateAdded: certificateEntry.dateAccepted
                ))
            }

            await MainActor.run {
                certificates = certInfos.sorted { $0.domain < $1.domain }
            }
        }
    }

    func deleteCertificates(at offsets: IndexSet) {
        Task {
            let store = CertificateManagers.certificateStore

            for index in offsets {
                let domain = certificates[index].domain
                await store.removeCertificate(forDomain: domain)
            }

            loadCertificates()
        }
    }
}

struct ServerCertificatesView: View {
    @StateObject private var viewModel = ServerCertificatesViewModel()

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
        .onAppear {
            viewModel.loadCertificates()
        }
    }

    private func deleteCertificates(offsets: IndexSet) {
        viewModel.deleteCertificates(at: offsets)
    }
}

#Preview {
    NavigationStack {
        ServerCertificatesView()
    }
}
