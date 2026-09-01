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

    // Shared row height keeps normal and edit mode visually identical.
    private static let rowHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            if showEditMode {
                editModeList
                    .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    ForEach(homes, id: \.self) { home in
                        homeRow(for: home)
                            .transition(.opacity)
                    }
                }
                .transition(.opacity)
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
                withAnimation(.easeInOut(duration: 0.3)) {
                    homes = Preferences.shared.listStoredHomes()
                }
            }
        }
        .alert(String(localized: "New Home"), isPresented: $showingNewHomeAlert) {
            TextField(String(localized: "Home name"), text: $newHomeName)
            Button(String(localized: "Cancel"), role: .cancel) {}
            Button(String(localized: "Create")) {
                Preferences.shared.createAndLoadNewStoredSettings(homeName: newHomeName)
                withAnimation(.easeInOut(duration: 0.3)) {
                    homes = Preferences.shared.listStoredHomes()
                }
                homeForSettings = Preferences.shared.currentHomePreferences.id
                withAnimation(.easeInOut(duration: 0.25)) { showEditMode = false }
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
            avatarView(for: home, isActive: isActive)

            Text(homeName)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let prefs {
                connectionSymbolsView(for: prefs)
            }

            // Gear opens Home Settings without triggering a home switch.
            Button(action: { homeForSettings = home }) {
                Image(systemSymbol: .gear)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(height: Self.rowHeight)
        .padding(.horizontal, 16)
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
        // List enforces a defaultMinListRowHeight independently of listRowInsets and
        // frame(height:) on row content. Override it so the List doesn't inflate rows
        // beyond our target height.
        .environment(\.defaultMinListRowHeight, Self.rowHeight)
        // List with scrollDisabled doesn't auto-shrink; fix the height so
        // the parent ScrollView remains in control of total menu scrolling.
        // .clipped() prevents the List from reporting a taller preferred size
        // than the frame to the parent VStack.
        .frame(height: CGFloat(homes.count) * Self.rowHeight)
        .clipped()
    }

    @ViewBuilder
    private func editModeRow(for home: UUID) -> some View {
        let homeName = Preferences.shared.storedHomes[home]?.homeName ?? ""
        let isActive = Preferences.shared.currentHomePreferences.id == home
        let prefs = Preferences.shared.storedHomeWithCredentials(forId: home)

        HStack(spacing: 8) {
            avatarView(for: home, isActive: isActive)

            Text(homeName)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let prefs {
                connectionSymbolsView(for: prefs)
            }

            // Active home cannot be deleted; show a dimmed trash to keep column alignment.
            Button(action: {
                homeNameForDeleteAlert = homeName
                homeForDeleteAlert = home
                showingDeleteAlert = true
            }) {
                Image(systemSymbol: .trash)
                    .foregroundStyle(isActive ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.red))
            }
            .buttonStyle(.plain)
            .disabled(isActive)
        }
        .frame(height: Self.rowHeight)
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

                Button(action: { withAnimation(.easeInOut(duration: 0.25)) { showEditMode = false } }) {
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
            Button(action: { withAnimation(.easeInOut(duration: 0.25)) { showEditMode = true } }) {
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

    /// Always renders a 28 × 28 avatar circle. Uses the home's custom image when
    /// available, falling back to a generic house icon. A blue ring overlaid when
    /// `isActive` replaces the separate checkmark, keeping row widths consistent.
    @ViewBuilder
    private func avatarView(for homeId: UUID, isActive: Bool) -> some View {
        Group {
            if let image = AvatarImageHelper.load(for: homeId) {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.12))
                    Image(systemSymbol: .houseFill)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(.circle)
        .overlay {
            if isActive {
                Circle()
                    .strokeBorder(.blue, lineWidth: 2)
            }
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
        let remote = prefs.remoteConnectionConfig
        if remote.supportsNotifications {
            // All three must be present: a server URL, a username, and a password.
            // username and password come from the Keychain (injected by
            // storedHomeWithCredentials); either being empty means the connection
            // will fail authentication even if the URL is correct.
            let isValid = !remote.url.isEmpty && !remote.username.isEmpty && !remote.password.isEmpty
            result.append(isValid ? .cloudFill : .cloudSlash)
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
                        symbolImage(for: symbol)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func symbolImage(for symbol: HomeConnectionSymbol) -> some View {
        switch symbol {
        case .wifi:
            Image(systemSymbol: .wifi)
        case .cloudFill:
            Image(systemSymbol: .cloudFill)
        case .cloudSlash:
            // Outline variant keeps the exclamation mark visible against light/grey backgrounds.
            Image(systemSymbol: .exclamationmarkIcloud)
        }
    }

    // MARK: - Home selection

    private func selectHome(_ home: UUID) {
        Preferences.shared.switchActiveHome(to: home)
        NotificationCenter.default.post(name: .homeDidSwitch, object: nil)
        isMenuPresented = false
    }
}
