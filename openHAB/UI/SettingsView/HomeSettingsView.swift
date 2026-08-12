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
import SwiftUI

struct HomeSettingsView: View {
    @StateObject private var networkTracker = MainActorNetworkTracker.shared
    /// When non-nil, the view edits the specified stored home instead of the active home.
    var homeId: UUID?

    /// Called after the sheet is dismissed via swipe with unsaved changes.
    /// The passed closure performs the save when invoked by the parent.
    var onDismissedDirty: ((SettingsSnapshot, @escaping () -> Void) -> Void)?
    var initialValues: SettingsSnapshot?

    @State private var settingsDemomode = false
    @State private var settingsRealTimeSliders = true
    @State private var settingsIconType: IconType = .svg
    @State private var settingsSortSitemapsBy: SortSitemapsOrder = .label
    @State private var settingsSitemapNameLabelDisplayMode: SitemapNameLabelDisplayMode = .label
    @State private var settingsDefaultMainUIPath = ""
    @State private var settingsAlwaysAllowWebRTC = true
    @State private var settingsSitemapForWatch = ""

    @State private var sitemaps: [OpenHABSitemap] = []
    @State private var settingsLocalConnectionConfiguration = ConnectionConfiguration(url: "", username: "", password: "")
    @State private var settingsRemoteConnectionConfiguration = ConnectionConfiguration(url: "", username: "", password: "")
    @State private var settingsHomeName = ""
    @State private var viewAppearedOnce = false
    @State private var settingsSSECommandItem = ""
    @State private var showLocalNetworkAlert = false
    @State private var loadedLocalURL = ""
    @State private var localTestedOKURL = ""

    @State private var initialSnapshot: SettingsSnapshot?
    @State private var isDirty = false
    @State private var savedExplicitly = false
    @State private var selectedSSEItemName: String?
    @State private var showAppSettings = false
    @State private var showCommandItemInfo = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    struct SettingsSnapshot: Equatable {
        var demomode: Bool
        var realTimeSliders: Bool
        var iconType: IconType
        var sortSitemapsBy: SortSitemapsOrder
        var sitemapNameLabelDisplayMode: SitemapNameLabelDisplayMode
        var defaultMainUIPath: String
        var alwaysAllowWebRTC: Bool
        var sitemapForWatch: String
        var localConnectionConfig: ConnectionConfiguration
        var remoteConnectionConfig: ConnectionConfiguration
        var sseCommandItem: String
    }

    private var currentSnapshot: SettingsSnapshot {
        SettingsSnapshot(
            demomode: settingsDemomode,
            realTimeSliders: settingsRealTimeSliders,
            iconType: settingsIconType,
            sortSitemapsBy: settingsSortSitemapsBy,
            sitemapNameLabelDisplayMode: settingsSitemapNameLabelDisplayMode,
            defaultMainUIPath: settingsDefaultMainUIPath,
            alwaysAllowWebRTC: settingsAlwaysAllowWebRTC,
            sitemapForWatch: settingsSitemapForWatch,
            localConnectionConfig: settingsLocalConnectionConfiguration,
            remoteConnectionConfig: settingsRemoteConnectionConfiguration,
            sseCommandItem: settingsSSECommandItem
        )
    }

    var body: some View {
        Form {
            ConnectionSettingsView(
                settingsDemomode: $settingsDemomode,
                localConnectionConfiguration: $settingsLocalConnectionConfiguration,
                remoteConnectionConfiguration: $settingsRemoteConnectionConfiguration,
                localTestedOKURL: $localTestedOKURL
            )

            Section(footer: Text(String(localized: "command_item_footer"))) {
                NavigationLink {
                    ItemSelectionView(selectedItemName: $selectedSSEItemName)
                } label: {
                    HStack {
                        Text("Command Item \(selectedSSEItemName?.isEmpty == false ? "(\(selectedSSEItemName ?? ""))" : "")")
                        Spacer()
                        Button {
                            showCommandItemInfo = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .onChange(of: selectedSSEItemName) { newSelection in
                settingsSSECommandItem = newSelection ?? ""
            }
            .onAppear {
                selectedSSEItemName = settingsSSECommandItem
            }

            MainUISettingsView(
                settingsAlwaysAllowWebRTC: $settingsAlwaysAllowWebRTC,
                settingsDefaultMainUIPath: $settingsDefaultMainUIPath
            )

            SitemapSettingsView(
                settingsRealTimeSliders: $settingsRealTimeSliders,
                settingsIconType: $settingsIconType,
                settingsSortSitemapsBy: $settingsSortSitemapsBy,
                settingsSitemapNameLabelDisplayMode: $settingsSitemapNameLabelDisplayMode,
                settingsSitemapForWatch: $settingsSitemapForWatch,
                sitemaps: $sitemaps
            )

            Section {
                Button {
                    showAppSettings = true
                } label: {
                    NavigationLink("App Settings", destination: EmptyView())
                }
                .foregroundStyle(isDirty ? Color.secondary : Color(uiColor: .label))
                .disabled(isDirty)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("\(settingsHomeName) Settings")
        .alert("Local Network Access Required", isPresented: $showLocalNetworkAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
                dismiss()
            }
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("To connect to your local openHAB server, please allow Local Network access when prompted. If you previously denied it, enable it in Settings → Privacy & Security → Local Network.")
        }
        .toolbar {
            if isDirty {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        savedExplicitly = true
                        saveSettings()
                        NotificationCenter.default.post(name: NSNotification.Name("org.openhab.preferences.saved"), object: nil)
                        if !settingsDemomode,
                           !settingsLocalConnectionConfiguration.url.isEmpty,
                           settingsLocalConnectionConfiguration.url != loadedLocalURL,
                           settingsLocalConnectionConfiguration.url != localTestedOKURL {
                            showLocalNetworkAlert = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    savedExplicitly = true // treat explicit X as intentional discard — no dialog
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
        .onDisappear {
            guard isDirty, !savedExplicitly else { return }
            // Sheet was swiped away with unsaved changes — capture values and notify parent
            let dm = settingsDemomode, rts = settingsRealTimeSliders
            let it = settingsIconType, ssb = settingsSortSitemapsBy
            let sdm = settingsSitemapNameLabelDisplayMode
            let dmu = settingsDefaultMainUIPath, aawrtc = settingsAlwaysAllowWebRTC
            let sfw = settingsSitemapForWatch
            let sfwLabel = sitemaps.first { $0.name == sfw }?.label ?? "unknown"
            let lcc = settingsLocalConnectionConfiguration
            let rcc = settingsRemoteConnectionConfiguration
            let sseCI = settingsSSECommandItem
            let targetId = homeId ?? Preferences.shared.currentHomePreferences.id
            let snapshot = currentSnapshot
            onDismissedDirty?(snapshot) {
                Preferences.shared.modifyStoredHome(targetId) { @MainActor prefs in
                    prefs.demomode = dm
                    prefs.realTimeSliders = rts
                    prefs.iconType = it.rawValue
                    prefs.sortSitemapsBy = ssb.rawValue
                    prefs.sitemapNameLabelDisplayMode = sdm
                    prefs.defaultMainUIPath = dmu
                    prefs.alwaysAllowWebRTC = aawrtc
                    prefs.sitemapForWatch = sfw
                    prefs.sitemapForWatchLabel = sfwLabel
                    prefs.localConnectionConfig = lcc
                    prefs.remoteConnectionConfig = rcc
                    prefs.sseCommandItem = sseCI
                }
                NotificationCenter.default.post(name: NSNotification.Name("org.openhab.preferences.saved"), object: nil)
            }
        }
        .onChange(of: currentSnapshot) { newSnapshot in
            isDirty = newSnapshot != initialSnapshot
        }
        .task {
            guard !viewAppearedOnce else { return }
            viewAppearedOnce = true
            loadSettings()
            initialSnapshot = currentSnapshot
            if let initialValues {
                applySnapshot(initialValues)
            }
        }
        .task(id: networkTracker.activeConnection) {
            guard let activeConnection = networkTracker.activeConnection else { return }
            await updateSitemaps(activeConfiguration: activeConnection.configuration)
        }
        .sheet(isPresented: $showAppSettings) {
            NavigationStack {
                AppSettingsView()
            }
        }
        .sheet(isPresented: $showCommandItemInfo) {
            CommandItemInfoSheet()
                .presentationDetents([.medium, .large])
        }
    }

    private func updateSitemaps(activeConfiguration: ConnectionConfiguration) async {
        do {
            let openAPIService = try OpenAPIService(connectionConfiguration: activeConfiguration)

            sitemaps = try await openAPIService.openHABSitemaps()
            if sitemaps.last?.name == "_default", sitemaps.count > 1 {
                sitemaps = Array(sitemaps.dropLast())
            }

            // Sort the sitemaps according to Settings selection.
            switch SortSitemapsOrder(rawValue: Preferences.shared.currentHomePreferences.sortSitemapsBy) ?? .label {
            case .label: sitemaps.sort { $0.label < $1.label }
            case .name: sitemaps.sort { $0.name < $1.name }
            }
        } catch {
            Logger.settingsView.error("\(error.localizedDescription)")
            sitemaps = []
        }
    }

    private func loadSettings() {
        #if !DEBUG
        Logger.settingsView.debug("Loading Settings")
        #endif
        let homePrefs: HomePreferences
        if let homeId, let stored = Preferences.shared.storedHomes[homeId] {
            homePrefs = stored
        } else {
            homePrefs = Preferences.shared.currentHomePreferences
        }
        settingsDemomode = homePrefs.demomode
        settingsRealTimeSliders = homePrefs.realTimeSliders
        settingsIconType = IconType(rawValue: homePrefs.iconType) ?? .svg
        settingsSortSitemapsBy = SortSitemapsOrder(rawValue: homePrefs.sortSitemapsBy) ?? .label
        settingsSitemapNameLabelDisplayMode = homePrefs.sitemapNameLabelDisplayMode
        settingsDefaultMainUIPath = homePrefs.defaultMainUIPath
        settingsAlwaysAllowWebRTC = homePrefs.alwaysAllowWebRTC
        settingsSitemapForWatch = homePrefs.sitemapForWatch
        settingsLocalConnectionConfiguration = homePrefs.localConnectionConfig
        settingsRemoteConnectionConfiguration = homePrefs.remoteConnectionConfig
        loadedLocalURL = homePrefs.localConnectionConfig.url
        settingsHomeName = homePrefs.homeName
        settingsSSECommandItem = homePrefs.sseCommandItem
    }

    private func applySnapshot(_ snapshot: SettingsSnapshot) {
        settingsDemomode = snapshot.demomode
        settingsRealTimeSliders = snapshot.realTimeSliders
        settingsIconType = snapshot.iconType
        settingsSortSitemapsBy = snapshot.sortSitemapsBy
        settingsSitemapNameLabelDisplayMode = snapshot.sitemapNameLabelDisplayMode
        settingsDefaultMainUIPath = snapshot.defaultMainUIPath
        settingsAlwaysAllowWebRTC = snapshot.alwaysAllowWebRTC
        settingsSitemapForWatch = snapshot.sitemapForWatch
        settingsLocalConnectionConfiguration = snapshot.localConnectionConfig
        settingsRemoteConnectionConfiguration = snapshot.remoteConnectionConfig
        settingsSSECommandItem = snapshot.sseCommandItem
    }

    func saveSettings() {
        let sitemapLabel = sitemaps.first { $0.name == settingsSitemapForWatch }?.label ?? "unknown"
        let targetId = homeId ?? Preferences.shared.currentHomePreferences.id
        Preferences.shared.modifyStoredHome(targetId) { @MainActor homePreferences in
            homePreferences.demomode = settingsDemomode
            homePreferences.realTimeSliders = settingsRealTimeSliders
            homePreferences.iconType = settingsIconType.rawValue
            homePreferences.sortSitemapsBy = settingsSortSitemapsBy.rawValue
            homePreferences.sitemapNameLabelDisplayMode = settingsSitemapNameLabelDisplayMode
            homePreferences.defaultMainUIPath = settingsDefaultMainUIPath
            homePreferences.alwaysAllowWebRTC = settingsAlwaysAllowWebRTC
            homePreferences.sitemapForWatch = settingsSitemapForWatch
            homePreferences.sitemapForWatchLabel = sitemapLabel
            homePreferences.localConnectionConfig = settingsLocalConnectionConfiguration
            homePreferences.remoteConnectionConfig = settingsRemoteConnectionConfiguration
            homePreferences.sseCommandItem = settingsSSECommandItem
        }
    }
}

private struct CommandItemInfoSheet: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Command Item")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(String(localized: "command_item_info_body"))
                    .font(.body)
                Button {
                    openURL(URL(string: "https://www.openhab.org/addons/integrations/openhabcloud/#action-syntax")!)
                } label: {
                    Label(String(localized: "command_item_docs_link"), systemImage: "arrow.up.right.square")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension UIApplication {
    var firstKeyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .first?.keyWindow
    }
}

#Preview {
    NavigationStack {
        HomeSettingsView()
    }
}
