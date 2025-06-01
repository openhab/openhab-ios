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
    @State private var homes: [UUID] = []

    @State private var showingNewHomeAlert = false
    @State private var newHomeName = ""

    @State private var showEditOptions = false

    @State private var showingRenameHomeAlert = false

    @State private var showingDeleteHomeAlert = false

    @Environment(\.dismiss) private var dismiss

    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

    private let logger = Logger(subsystem: "org.openhab.app", category: "SettingsView")

    var body: some View {
        List(homes, id: \.self) { home in
            let homeName = Preferences.storedPreferences[home.uuidString]?["homeName"] as? String ?? ""
            HStack {
                HStack {
                    if showEditOptions {
                        Image(systemSymbol: .pencil)
                    }
                    Text(homeName)
                    // TODO: selection of name in list changes settings
                    // TODO: options like remove, rename (or should we rename in settings?)
                    if Preferences.currentlyUsedSettings == home.uuidString, !showEditOptions {
                        Spacer()
                        Image(systemSymbol: .checkmark)
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(.interaction, Rectangle())
                .onTapGesture {
                    if !showEditOptions {
                        Preferences.switchCurrentlyUsedSettings(to: home)
                        dismiss()
                    } else {
                        newHomeName = homeName
                        showingRenameHomeAlert.toggle()
                    }
                }
                .alert("Enter new name", isPresented: $showingRenameHomeAlert) {
                    TextField("New name for home", text: $newHomeName)
                    HStack {
                        Button("Abort") {
                            showingRenameHomeAlert.toggle()
                        }
                        Button("OK") {
                            rename(home: home)
                            showingRenameHomeAlert.toggle()
                        }
                    }
                }
                if showEditOptions {
                    HStack {
                        Spacer()
                        if Preferences.currentlyUsedSettings != home.uuidString {
                            Button(action: {
                                showingDeleteHomeAlert.toggle()
                            }, label: {
                                Image(systemSymbol: .trash)
                            })
                            .alert("Delete home \(homeName)?", isPresented: $showingDeleteHomeAlert) {
                                HStack {
                                    Button("Abort") {
                                        showingDeleteHomeAlert.toggle()
                                    }
                                    Button("OK") {
                                        delete(home: home)
                                        showingDeleteHomeAlert.toggle()
                                    }
                                }
                            }
                        } else {
                            Image(systemSymbol: .checkmark)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .onAppear(perform: loadHomesList)
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
                        newHomeName = ""
                        showingNewHomeAlert.toggle()
                    }, label: {
                        Image(systemSymbol: .plus)
                    })
                    .alert("Enter name for new home", isPresented: $showingNewHomeAlert) {
                        TextField("Name for new home", text: $newHomeName)
                        HStack {
                            Button("Abort") {
                                showingNewHomeAlert.toggle()
                            }
                            Button("OK") {
                                addHome()
                                showingNewHomeAlert.toggle()
                            }
                        }
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

    private func loadHomesList() {
        homes = Preferences.listStoredPreferences()
    }

    private func delete(home toDelete: UUID) {
        os_log("delete home settings for %@", toDelete.uuidString)
        Preferences.deleteStoredSettings(toDelete)
        loadHomesList()
    }

    private func rename(home toRename: UUID) {
        let newName = newHomeName
        os_log("rename home %@ to %@", toRename.uuidString, newName)
        if toRename == Preferences.getCurrentlyUsedSettings() {
            Preferences.homeName = newName
        } else {
            Preferences.renameHome(toRename, newHomeName: newName)
        }
        loadHomesList()
    }

    private func addHome() {
        Preferences.createAndLoadNewStoredSettings(homeName: newHomeName)
        loadHomesList()
    }
}

#Preview {
    HomeSelectionView()
}
