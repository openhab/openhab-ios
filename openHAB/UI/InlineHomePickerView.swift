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

// MARK: - Connection symbol model

/// Symbols shown in each home row to communicate configured connection types.
/// Derived purely from stored preferences — no live connection state.
enum HomeConnectionSymbol: Hashable {
    /// Local server URL is configured.
    case wifi
    /// Cloud/remote connection configured with credentials.
    case cloudFill
    /// Cloud/remote connection configured but credentials are missing.
    case cloudSlash
}

// MARK: - Inline home picker

struct InlineHomePickerView: View {
    @Binding var isMenuPresented: Bool

    @State private var homes: [UUID] = []
    @State private var showEditMode = false
    @State private var homeForSettings: UUID?

    @State private var homeForDeleteAlert = UUID()
    @State private var homeNameForDeleteAlert = ""
    @State private var newHomeName = ""
    @State private var showingDeleteAlert = false
    @State private var showingNewHomeAlert = false

    var body: some View {
        VStack(spacing: 0) {
            if showEditMode {
                editModeList
            } else {
                ForEach(homes, id: \.self) { home in
                    homeRow(for: home)
                }
            }
            Divider().padding(.horizontal, 12)
            actionBar
        }
        .onAppear { homes = Preferences.shared.listStoredHomes() }
        .alert(
            String(localized: "Delete '\(homeNameForDeleteAlert)'?"),
            isPresented: $showingDeleteAlert
        ) {
            Button(String(localized: "Cancel"), role: .cancel) {}
            Button(String(localized: "Delete"), role: .destructive) {
                Preferences.shared.deleteStoredHome(homeForDeleteAlert)
                homes = Preferences.shared.listStoredHomes()
            }
        }
        .alert(String(localized: "New Home"), isPresented: $showingNewHomeAlert) {
            TextField(String(localized: "Home name"), text: $newHomeName)
            Button(String(localized: "Cancel"), role: .cancel) {}
            Button(String(localized: "Create")) {
                Preferences.shared.createAndLoadNewStoredSettings(homeName: newHomeName)
                homes = Preferences.shared.listStoredHomes()
                homeForSettings = Preferences.shared.currentHomePreferences.id
                showEditMode = false
            }
        } message: {
            Text("For Shortcuts to work across multiple devices, each home must have the same name on every device.")
        }
        .sheet(
            isPresented: Binding(
                get: { homeForSettings != nil },
                set: { if !$0 { homeForSettings = nil } }
            )
        ) {
            if let target = homeForSettings {
                NavigationStack {
                    HomeSettingsView(homeId: target)
                }
            }
        }
    }

    // MARK: - Normal-mode home row

    @ViewBuilder
    private func homeRow(for home: UUID) -> some View {
        let homeName = Preferences.shared.storedHomes[home]?.homeName ?? ""
        let isActive = Preferences.shared.currentHomePreferences.id == home
        let prefs = Preferences.shared.storedHomeWithCredentials(forId: home)

        HStack(spacing: 8) {
            avatarView(for: home)

            Text(homeName)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let prefs {
                connectionSymbolsView(for: prefs)
            }

            if isActive {
                Image(systemSymbol: .checkmark)
                    .foregroundStyle(.blue)
            }

            // Gear opens Home Settings without triggering a home switch.
            Button(action: { homeForSettings = home }) {
                Image(systemSymbol: .gear)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { selectHome(home) }
    }

    // MARK: - Edit-mode list (drag-to-reorder)

    private var editModeList: some View {
        List {
            ForEach(homes, id: \.self) { home in
                editModeRow(for: home)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
            .onMove { source, destination in
                homes.move(fromOffsets: source, toOffset: destination)
                Preferences.shared.updateHomeOrder(homes)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
        .environment(\.editMode, .constant(.active))
        // List with scrollDisabled doesn't auto-shrink; fix the height so
        // the parent ScrollView remains in control of total menu scrolling.
        .frame(height: CGFloat(homes.count) * 52)
    }

    @ViewBuilder
    private func editModeRow(for home: UUID) -> some View {
        let homeName = Preferences.shared.storedHomes[home]?.homeName ?? ""
        let isActive = Preferences.shared.currentHomePreferences.id == home
        let prefs = Preferences.shared.storedHomeWithCredentials(forId: home)

        HStack(spacing: 8) {
            Text(homeName)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let prefs {
                connectionSymbolsView(for: prefs)
            }

            if isActive {
                Image(systemSymbol: .checkmark)
                    .foregroundStyle(.blue)
            } else {
                Button(action: {
                    homeNameForDeleteAlert = homeName
                    homeForDeleteAlert = home
                    showingDeleteAlert = true
                }) {
                    Image(systemSymbol: .trash)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        // Fixed height matches the frame(height:) calculation above.
        .frame(height: 52)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }

    // MARK: - Action bar

    @ViewBuilder
    private var actionBar: some View {
        if showEditMode {
            // Edit mode: full-width "Add Home" above full-width "Done"
            VStack(spacing: 0) {
                Button(action: { newHomeName = ""; showingNewHomeAlert = true }) {
                    HStack(spacing: 4) {
                        Image(systemSymbol: .plus)
                        Text("Add Home")
                    }
                    .font(.footnote)
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.plain)

                Divider()

                Button(action: { showEditMode = false }) {
                    Text("Done")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        } else {
            // Normal mode: single Edit button — add/delete/reorder only in edit mode
            Button(action: { showEditMode = true }) {
                Text("Edit")
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Avatar

    @ViewBuilder
    private func avatarView(for homeId: UUID) -> some View {
        if let image = AvatarImageHelper.load(for: homeId) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(.circle)
        }
    }

    // MARK: - Connection symbols

    /// Maps a home's stored configuration to an ordered list of display symbols.
    ///
    /// This is a pure static function so it can be exercised by unit tests
    /// without constructing a view.
    static func connectionSymbols(for prefs: HomePreferences) -> [HomeConnectionSymbol] {
        guard !prefs.demomode else { return [] }
        var result: [HomeConnectionSymbol] = []
        if !prefs.localConnectionConfig.url.isEmpty {
            result.append(.wifi)
        }
        // `supportsNotifications` is the "openHAB Cloud Service" toggle.
        // When it is off the user has explicitly disabled cloud; show no symbol.
        if prefs.remoteConnectionConfig.supportsNotifications {
            result.append(
                prefs.remoteConnectionConfig.username.isEmpty ? .cloudSlash : .cloudFill
            )
        }
        return result
    }

    @ViewBuilder
    private func connectionSymbolsView(for prefs: HomePreferences) -> some View {
        if prefs.demomode {
            Text("Demo")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            let symbols = Self.connectionSymbols(for: prefs)
            if !symbols.isEmpty {
                HStack(spacing: 4) {
                    ForEach(symbols, id: \.self) { symbol in
                        Image(systemSymbol: sfSymbol(for: symbol))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func sfSymbol(for symbol: HomeConnectionSymbol) -> SFSymbol {
        switch symbol {
        case .wifi: .wifi
        case .cloudFill: .cloudFill
        case .cloudSlash: .cloudSlash
        }
    }

    // MARK: - Home selection

    private func selectHome(_ home: UUID) {
        Preferences.shared.switchActiveHome(to: home)
        NotificationCenter.default.post(name: .homeDidSwitch, object: nil)
        isMenuPresented = false
    }
}
