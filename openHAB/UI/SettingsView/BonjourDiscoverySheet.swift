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
import SFSafeSymbols
import SwiftUI

struct BonjourDiscoverySheet: View {
    @Binding var isPresented: Bool
    @Binding var connectionConfig: ConnectionConfiguration
    @StateObject private var discovery = BonjourDiscoveryViewModel()

    var body: some View {
        NavigationStack {
            List {
                if discovery.isDiscovering {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("discovering_servers")
                                .padding(.vertical, 8)
                            Spacer()
                        }
                    }
                }

                Section {
                    if discovery.discoveredURLs.isEmpty {
                        if !discovery.isDiscovering {
                            HStack {
                                Spacer()
                                Text("no_servers_found")
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 8)
                                Spacer()
                            }
                        }
                    } else {
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
                } footer: {
                    if !discovery.isDiscovering {
                        Text("bonjour_discovery_disclaimer")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("discovered_servers")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .task {
            discovery.resetDiscoveredUrls()
            discovery.discoverAll()
        }
        .onDisappear {
            discovery.resetDiscoveredUrls()
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    @Previewable @State var connectionConfig = ConnectionConfiguration(
        url: "https://openhab.local:8443",
        username: "user",
        password: "password123"
    )

    NavigationStack {
        Form {
            BonjourDiscoverySheet(isPresented: $isPresented, connectionConfig: $connectionConfig)
        }
    }
}
