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
import SFSafeSymbols
import SwiftUI

struct BonjourDiscoverySheet: View {
    @Binding var isPresented: Bool
    @Binding var connectionConfig: ConnectionConfiguration
    @StateObject private var discovery = BonjourDiscoveryViewModel()

    var body: some View {
        NavigationView {
            List {
                if discovery.isDiscovering {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Discovering openHAB servers…")
                                .padding(.vertical, 8)
                            Spacer()
                        }
                    }
                }

                Section {
                    ForEach(
                        discovery.discoveredURLs
                            .sorted {
                                if $0.hasPrefix("https") == $1.hasPrefix("https") {
                                    $0 < $1
                                } else {
                                    $0.hasPrefix("https")
                                }
                            },
                        id: \.self
                    ) { url in
                        Button(action: {
                            connectionConfig.url = url
                            isPresented = false
                        }, label: {
                            HStack {
                                Text(url)
                                Spacer()
                                if connectionConfig.url == url {
                                    Image(systemSymbol: .checkmark)
                                }
                            }
                        })
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Discovered Servers")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .task {
            discovery.resetDiscoveredUrls()
            discovery.discoverSequentially()
        }
    }
}

// #Preview {
//    BonjourDiscoverySheet(isPresented: <#Binding<Bool>#>, connectionConfig: <#Binding<ConnectionConfiguration>#>, discovery: <#BonjourDiscoveryViewModel#>)
// }
