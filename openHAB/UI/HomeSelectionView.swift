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
import os
import SFSafeSymbols
import SwiftUI

// MARK: - HomeRowView

private struct HomeRowView: View {
    let home: UUID
    let homeName: String
    let isActive: Bool
    let showEditOptions: Bool
    let onSelect: () -> Void
    let onDeleteRequested: () -> Void
    let onRenameRequested: () -> Void

    var body: some View {
        HStack {
            HStack {
                if showEditOptions {
                    Image(systemSymbol: .pencil)
                        .foregroundStyle(.blue)
                }
                Text(homeName)
                if isActive, !showEditOptions {
                    Spacer()
                    Image(systemSymbol: .checkmark)
                        .foregroundStyle(.blue)
                } else if !showEditOptions {
                    Spacer()
                }
            }
            .contentShape(.interaction, Rectangle())
            .onTapGesture {
                if showEditOptions {
                    onRenameRequested()
                } else {
                    onSelect()
                }
            }
            if showEditOptions {
                HStack {
                    Spacer()
                    if !isActive {
                        Button(action: onDeleteRequested) {
                            Image(systemSymbol: .trash)
                        }
                    } else {
                        Image(systemSymbol: .checkmark)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !isActive {
                Button(role: .destructive, action: onDeleteRequested) {
                    HStack {
                        Text("Delete")
                        Image(systemSymbol: .trashFill)
                    }
                }
                .tint(.red)
            }
        }
        .swipeActions(edge: .leading) {
            Button(action: onRenameRequested) {
                HStack {
                    Image(systemSymbol: .pencil)
                    Text("Rename")
                }
            }
            .tint(.blue)
        }
    }
}

struct HomeSelectionView: View {
    @State private var homes: [UUID] = []
    @State private var showingNewHomeAlert = false
    @State private var newHomeName = ""
    @State private var showEditOptions = false
    @State private var homeForAlert = UUID()
    @State private var homeNameForAlert = ""
    @State private var showingRenameHomeAlert = false
    @State private var showingDeleteHomeAlert = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Label {
                    Text("For Shortcuts to work across multiple devices, each home must have the same name on every device.")
                        .font(.subheadline)
                } icon: {
                    Image(systemSymbol: .infoCircleFill)
                        .foregroundStyle(.blue)
                }
            }

            Section {
                ForEach(homes, id: \.self) { home in
                    let homeName = Preferences.shared.storedHomes[home]?.homeName ?? ""
                    HomeRowView(
                        home: home,
                        homeName: homeName,
                        isActive: Preferences.shared.currentHomePreferences.id == home,
                        showEditOptions: showEditOptions,
                        onSelect: { select(home: home) },
                        onDeleteRequested: {
                            homeNameForAlert = homeName
                            homeForAlert = home
                            showingDeleteHomeAlert = true
                        },
                        onRenameRequested: {
                            homeNameForAlert = homeName
                            homeForAlert = home
                            newHomeName = homeName
                            showingRenameHomeAlert = true
                        }
                    )
                }
            }
        }
        .alert("Enter a new name for the home '\(homeNameForAlert)'", isPresented: $showingRenameHomeAlert) {
            TextField("New name", text: $newHomeName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") { rename(home: homeForAlert) }
        } message: {
            Text("Warning: Renaming the home might cause external integrations like shortcuts to fail until reconfigured.")
        }
        .alert("Delete home '\(homeNameForAlert)'?", isPresented: $showingDeleteHomeAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { delete(home: homeForAlert) }
        }
        .onAppear(perform: loadHomesList)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitle("Manage Homes")
        .toolbar(content: toolbar)
    }

    @ToolbarContentBuilder
    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemSymbol: .chevronBackward)
                    .accessibilityLabel("Back")
            }
        }
        if showEditOptions {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    newHomeName = "Home#\(homes.count + 1)"
                    showingNewHomeAlert.toggle()
                } label: {
                    Image(systemSymbol: .plus)
                }
                .alert("Enter a name for the new home", isPresented: $showingNewHomeAlert) {
                    TextField("Name for new home", text: $newHomeName)
                    Button("Cancel", role: .cancel) {}
                    Button("Create") { addHome() }
                }
                Button { showEditOptions.toggle() } label: {
                    Image(systemSymbol: .checkmark)
                }
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                Button { showEditOptions.toggle() } label: {
                    Image(systemSymbol: .pencil)
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

    private func delete(home toDelete: UUID) {
        Logger.selectionView.info("delete home settings for \(toDelete.uuidString)")
        Preferences.shared.deleteStoredHome(toDelete)
        loadHomesList()
    }

    private func rename(home toRename: UUID) {
        Logger.selectionView.info("rename home \(toRename.uuidString) to \(newHomeName)")
        Preferences.shared.renameHome(toRename, newHomeName: newHomeName)
    }

    private func addHome() {
        Preferences.shared.createAndLoadNewStoredSettings(homeName: newHomeName)
        loadHomesList()
    }
}

#Preview {
    HomeSelectionView()
}
