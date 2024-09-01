// Copyright (c) 2010-2024 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import SwiftUI

struct ClientCertificatesView: View {
    @StateObject private var viewModel = ClientCertificatesViewModel()

    var body: some View {
        List {
            ForEach(viewModel.clientCertificates.indices, id: \.self) { index in
                Text(viewModel.getIdentityName(for: index))
            }
            .onDelete { indices in
                indices.forEach { viewModel.deleteCertificate(at: $0) }
            }
        }
        .navigationTitle(Text(NSLocalizedString("client_certificates", comment: "")))
        .onAppear {
            viewModel.loadCertificates()
        }
    }
}

#Preview {
    ClientCertificatesView()
}
