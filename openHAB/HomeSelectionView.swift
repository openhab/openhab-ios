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

    @State private var homeForAlert = UUID() // just a random uuid to init
    @State private var homeNameForAlert = ""

    @State private var showingRenameHomeAlert = false

    @State private var showingDeleteHomeAlert = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(homes, id: \.self) { home in
            let homeName = Preferences.shared.storedHomes[home]?.homeName ?? ""
            HStack {
                HStack {
                    if showEditOptions {
                        Image(systemSymbol: .pencil)
                            .foregroundStyle(.blue)
                    }
                    Text(homeName)
                    if Preferences.shared.currentHomePreferences.id == home, !showEditOptions {
                        Spacer()
                        Image(systemSymbol: .checkmark)
                            .foregroundStyle(.blue)
                    } else if !showEditOptions {
                        Spacer() // make more of the cell clickable
                    }
                }
                .contentShape(.interaction, Rectangle())
                .onTapGesture {
                    homeNameForAlert = homeName
                    homeForAlert = home
                    newHomeName = homeName
                    if !showEditOptions {
                        select(home: home)
                    } else {
                        showingRenameHomeAlert.toggle()
                    }
                }
                if showEditOptions {
                    HStack {
                        Spacer()
                        if Preferences.shared.currentHomePreferences.id != home {
                            Button(action: {
                                homeNameForAlert = homeName
                                homeForAlert = home
                                showingDeleteHomeAlert.toggle()
                            }, label: {
                                Image(systemSymbol: .trash)
                            })
                        } else {
                            Image(systemSymbol: .checkmark)
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .alert("Enter a new name for the home '\(homeNameForAlert)'", isPresented: $showingRenameHomeAlert, actions: {
                TextField("New name", text: $newHomeName)
                HStack {
                    Button("Cancel", role: .cancel) {
                        showingRenameHomeAlert.toggle()
                    }
                    Button("Rename") {
                        rename(home: homeForAlert)
                        showingRenameHomeAlert.toggle()
                    }
                }
            }, message: {
                Text("Warning: Renaming the home might cause external integrations like shortcuts to fail until reconfigured")
            })
            .alert("Delete home '\(homeNameForAlert)'?", isPresented: $showingDeleteHomeAlert) {
                HStack {
                    Button("Cancel", role: .cancel) {
                        showingDeleteHomeAlert.toggle()
                    }
                    Button("Delete", role: .destructive) {
                        delete(home: homeForAlert)
                        showingDeleteHomeAlert.toggle()
                    }
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive, action: {
                    delete(home: home)
                }, label: {
                    HStack {
                        Text("Delete")
                        Image(systemSymbol: .trashFill)
                    }
                })
                .tint(.red)
            }
            .swipeActions(edge: .leading) {
                Button(action: {
                    homeNameForAlert = homeName
                    homeForAlert = home
                    showingRenameHomeAlert.toggle()
                }, label: {
                    HStack {
                        Image(systemSymbol: .pencil)
                        Text("Rename")
                    }
                })
                .tint(.blue)
            }
        }
        .onAppear(perform: loadHomesList)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitle("Manage Homes")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    dismiss()
                }, label: {
                    Image(systemSymbol: .chevronBackward)
                        .accessibilityLabel("Back")
                })
            }
            if showEditOptions {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: {
                        newHomeName = ""
                        showingNewHomeAlert.toggle()
                    }, label: {
                        Image(systemSymbol: .plus)
                    })
                    .alert("Enter a name for the new home", isPresented: $showingNewHomeAlert) {
                        TextField("Name for new home", text: $newHomeName)
                        HStack {
                            Button("Cancel", role: .cancel) {
                                showingNewHomeAlert.toggle()
                            }
                            Button("Create") {
                                addHome()
                                showingNewHomeAlert.toggle()
                            }
                        }
                    }
                    Button(action: {
                        showEditOptions.toggle()
                    }, label: {
                        Image(systemSymbol: .checkmark)
                    })
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

    private func select(home: UUID) {
        Preferences.shared.switchActiveHome(to: home)
        dismiss()
    }

    private func loadHomesList() {
        homes = Preferences.shared.listStoredHomes()
    }

    private func delete(home toDelete: UUID?) {
        guard let toDelete else {
            return
        }
        Logger.selectionView.info("delete home settings for \(toDelete.uuidString)")
        Preferences.shared.deleteStoredHome(toDelete)
        loadHomesList()
    }

    private func rename(home toRename: UUID?) {
        guard let toRename else {
            return
        }
        let newName = newHomeName
        Logger.selectionView.info("rename home \(toRename.uuidString) to \(newName)")
        Preferences.shared.renameHome(toRename, newHomeName: newName)
    }

    private func addHome() {
        Preferences.shared.createAndLoadNewStoredSettings(homeName: newHomeName)
        loadHomesList()
    }
}

#Preview {
    HomeSelectionView()
}
