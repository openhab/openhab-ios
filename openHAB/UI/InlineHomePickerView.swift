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

struct InlineHomePickerView: View {
    @Binding var isMenuPresented: Bool

    @State private var homes: [UUID] = []
    @State private var showEditMode = false
    @State private var homeForSettings: UUID?

    @State private var homeForAlert = UUID()
    @State private var homeNameForAlert = ""
    @State private var newHomeName = ""

    @State private var showingRenameAlert = false
    @State private var showingDeleteAlert = false
    @State private var showingNewHomeAlert = false

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(homes, id: \.self) { home in
                    let homeName = Preferences.shared.storedHomes[home]?.homeName ?? ""
                    let isActive = Preferences.shared.currentHomePreferences.id == home
                    HStack(spacing: 8) {
                        if showEditMode {
                            Button(action: {
                                homeNameForAlert = homeName
                                homeForAlert = home
                                newHomeName = homeName
                                showingRenameAlert = true
                            }, label: {
                                Image(systemSymbol: .pencil).foregroundStyle(.blue)
                            })
                            .buttonStyle(.plain)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(homeName).font(.subheadline).fontWeight(.medium)
                            Text(summaryText(for: home))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !showEditMode else { return }
                            selectHome(home)
                        }
                        if showEditMode {
                            if isActive {
                                Image(systemSymbol: .checkmark).foregroundStyle(.blue)
                            } else {
                                Button(action: {
                                    homeNameForAlert = homeName
                                    homeForAlert = home
                                    showingDeleteAlert = true
                                }, label: {
                                    Image(systemSymbol: .trash).foregroundStyle(.red)
                                })
                                .buttonStyle(.plain)
                            }
                        } else {
                            if isActive {
                                Image(systemSymbol: .checkmark)
                                    .foregroundStyle(.blue)
                                    .padding(.trailing, 4)
                            }
                            Button(action: {
                                homeForSettings = home
                            }, label: {
                                Image(systemSymbol: .gear).foregroundStyle(.secondary)
                            })
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(action: {
                            homeNameForAlert = homeName
                            homeForAlert = home
                            showingDeleteAlert = true
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
                            newHomeName = homeName
                            showingRenameAlert = true
                        }, label: {
                            HStack {
                                Image(systemSymbol: .pencil)
                                Text("Rename")
                            }
                        })
                        .tint(.blue)
                    }
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .frame(height: max(CGFloat(homes.count) * 66, 1))

            Divider().padding(.horizontal, 12)

            HStack(spacing: 0) {
                Button(action: {
                    newHomeName = ""
                    showingNewHomeAlert = true
                }, label: {
                    HStack(spacing: 4) {
                        Image(systemSymbol: .plus)
                        Text("Add Home")
                    }
                    .font(.footnote)
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                })
                .buttonStyle(.plain)

                Divider().frame(height: 20)

                Button(action: {
                    showEditMode.toggle()
                }, label: {
                    HStack(spacing: 4) {
                        Image(systemSymbol: showEditMode ? .checkmark : .pencil)
                        Text(showEditMode ? String(localized: "Done") : String(localized: "Edit"))
                    }
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                })
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
        .onAppear { homes = Preferences.shared.listStoredHomes() }
        .alert(
            String(localized: "Rename '\(homeNameForAlert)'"),
            isPresented: $showingRenameAlert,
            actions: {
                TextField(String(localized: "New name"), text: $newHomeName)
                Button(String(localized: "Cancel"), role: .cancel) {}
                Button(String(localized: "Rename")) {
                    Preferences.shared.renameHome(homeForAlert, newHomeName: newHomeName)
                    homes = Preferences.shared.listStoredHomes()
                }
            },
            message: {
                Text("Warning: Renaming might break external integrations like shortcuts.")
            }
        )
        .alert(
            String(localized: "Delete '\(homeNameForAlert)'?"),
            isPresented: $showingDeleteAlert,
            actions: {
                Button(String(localized: "Cancel"), role: .cancel) {}
                Button(String(localized: "Delete"), role: .destructive) {
                    Preferences.shared.deleteStoredHome(homeForAlert)
                    homes = Preferences.shared.listStoredHomes()
                }
            }
        )
        .alert(
            String(localized: "New Home"),
            isPresented: $showingNewHomeAlert,
            actions: {
                TextField(String(localized: "Home name"), text: $newHomeName)
                Button(String(localized: "Cancel"), role: .cancel) {}
                Button(String(localized: "Create")) {
                    Preferences.shared.createAndLoadNewStoredSettings(homeName: newHomeName)
                    homes = Preferences.shared.listStoredHomes()
                    homeForSettings = Preferences.shared.currentHomePreferences.id
                }
            }
        )
        .sheet(
            isPresented: Binding(
                get: { homeForSettings != nil },
                set: { if !$0 { homeForSettings = nil } }
            ),
            content: {
                if let target = homeForSettings {
                    NavigationStack {
                        SettingsView(homeId: target)
                    }
                }
            }
        )
    }

    private func summaryText(for homeId: UUID) -> String {
        guard let prefs = Preferences.shared.storedHomes[homeId] else { return "" }
        var parts: [String] = []
        let localHost = prefs.localConnectionConfig.url.isEmpty
            ? String(localized: "Not set")
            : (URL(string: prefs.localConnectionConfig.url)?.host ?? prefs.localConnectionConfig.url)
        parts.append("Local: \(localHost)")
        let remoteHost = prefs.remoteConnectionConfig.url.isEmpty
            ? String(localized: "Not set")
            : (URL(string: prefs.remoteConnectionConfig.url)?.host ?? prefs.remoteConnectionConfig.url)
        parts.append("Remote: \(remoteHost)")
        let hasCredentials = !prefs.localConnectionConfig.username.isEmpty
            || !prefs.remoteConnectionConfig.username.isEmpty
        if !hasCredentials { parts.append(String(localized: "No credentials")) }
        if prefs.localConnectionConfig.ignoreSSL || prefs.remoteConnectionConfig.ignoreSSL {
            parts.append("SSL off")
        }
        if prefs.demomode { parts.append("Demo") }
        return parts.joined(separator: " · ")
    }

    private func selectHome(_ home: UUID) {
        Preferences.shared.switchActiveHome(to: home)
        NotificationCenter.default.post(name: .homeDidSwitch, object: nil)
        isMenuPresented = false
    }
}
