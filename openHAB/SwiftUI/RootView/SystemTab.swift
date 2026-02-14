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

import OpenHABCore
import SFSafeSymbols
import SwiftUI

// Display the connected URL
struct ConnectionView: View {
    @StateObject private var networkTracker = MainActorNetworkTracker.shared

    var body: some View {
        HStack {
            if let activeConnection = networkTracker.activeConnection {
                Image(systemSymbol: .cloudFill)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                Text(activeConnection.configuration.url).font(.footnote)
            } else {
                Image(systemSymbol: .exclamationmarkIcloudFill)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                Text("connecting").font(.footnote)
            }
        }
    }
}

struct SystemTab: View {
    @State private var showNotifications = false
    @State var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label {
                            Text(LocalizedStringKey("settings"))
                        } icon: {
                            Image(systemSymbol: .gear)
                        }
                    }

                    if showNotifications {
                        NavigationLink {
                            NotificationsView()
                        } label: {
                            Label {
                                Text(LocalizedStringKey("notifications"))
                            } icon: {
                                Image(systemSymbol: .bell)
                            }
                        }
                    }

                    NavigationLink {
                        HomeSelectionView()
                    } label: {
                        Label {
                            Text("Manage Homes")
                        } icon: {
                            Image(systemSymbol: .house)
                        }
                    }
                }
            }
            .navigationTitle("System")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                ConnectionView()
                    .padding(.bottom, 8)
            }
        }
        .task {
            updateNotificationVisibility()
        }
        .onReceive(Preferences.shared.$currentHomePreferences) { _ in
            updateNotificationVisibility()
        }
    }

    func resetToRoot() {
        path = NavigationPath()
    }

    private func updateNotificationVisibility() {
        showNotifications = Preferences.shared.getNotificationConnection() != nil
            && !Preferences.shared.currentHomePreferences.demomode
    }
}
