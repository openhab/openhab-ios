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

import FirebaseCrashlytics
import Kingfisher
import OpenHABCore
import os
import SafariServices
import SFSafeSymbols
import SwiftUI
import WebKit

struct HomeSelectionView: View {
    @State private var showingCacheAlert = false
    @State private var showCrashReportingAlert = false
    @State private var showUselastPathAlert = false

    @State private var homes: [UUID] = []

    @State private var showingNewHomeAlert = false
    @State private var newHomeName = ""

    @State private var showEditOptions = false

    @State private var showingRenameHomeAlert = false

    @Environment(\.dismiss) private var dismiss

    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

    private let logger = Logger(subsystem: "org.openhab.app", category: "SettingsView")

    var body: some View {
        List(homes, id: \.self) { home in
            HStack {
                HStack {
                    Text(Preferences.storedPreferences[home.uuidString]?["homeName"] as? String ?? "")
                    // TODO: selection of name in list changes settings
                    // TODO: options like remove, rename (or should we rename in settings?)
                    Spacer()
                    if Preferences.currentlyUsedSettings == home.uuidString {
                        Image(systemSymbol: .checkmark)
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(.interaction, Rectangle()) // Ensures entire row is tappable
                .onTapGesture {
                    if !showEditOptions {
                        Preferences.switchCurrentlyUsedSettings(to: home)
                        dismiss()
                    }
                }
                HStack {
                    if showEditOptions {
                        if Preferences.currentlyUsedSettings != home.uuidString {
                            Button(action: {
                                delete(home: home)
                            }, label: {
                                Image(systemSymbol: .trash)
                            })
                        }
                        Button(action: {
                            showingRenameHomeAlert.toggle()
                        }, label: {
                            Image(systemSymbol: .pencil)
                        })
                        .alert("Enter new name", isPresented: $showingRenameHomeAlert) {
                            TextField("Name for new home", text: $newHomeName)
                            Button("OK") {
                                rename(home: home)
                                showingRenameHomeAlert.toggle()
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            homes = Preferences.listStoredPreferences()
        }
        .navigationBarTitle("homeSelection")
        .toolbar {
            if showEditOptions {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: {
                        showEditOptions.toggle()
                    }, label: {
                        Image(systemSymbol: .checkmark)
                    })
                    Button(action: {
                        showingNewHomeAlert.toggle()
                    }, label: {
                        Image(systemSymbol: .plus)
                    })
                    .alert("Enter name for new home", isPresented: $showingNewHomeAlert) {
                        TextField("Name for new home", text: $newHomeName)
                        Button("OK", action: addHome)
                    }
                }
            } else {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: {
                        showEditOptions.toggle()
                    }, label: {
                        Image(systemSymbol: .pencil)
                    })
                }
            }
        }
    }

    private func delete(home toDelete: UUID) {
        os_log("delete home settings for %@", toDelete.uuidString)
        // TODO: preferences remove stored home settings, reload view
    }

    private func rename(home toRename: UUID) {
        // TODO: rename home in settings, reload view
        let newName = newHomeName
        os_log("rename home %@ to %@", toRename.uuidString, newName)
    }

    private func addHome() {
        Preferences.createAndLoadNewStoredSettings(homeName: newHomeName)
        dismiss()
    }
}

#Preview {
    HomeSelectionView()
}
