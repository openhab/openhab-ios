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
import PhotosUI
import SwiftUI

private struct CropSource: Identifiable {
    let id = UUID()
    enum Kind {
        case photoItem(PhotosPickerItem)
        case uiImage(UIImage)
    }
    let kind: Kind
}

struct HomeSettingsView: View {
    @ObservedObject private var networkTracker = MainActorNetworkTracker.shared
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
    /// The label last persisted for `settingsSitemapForWatch`. Falls back to this
    /// instead of "unknown" when `sitemaps` has no fresh match — e.g. for an inactive
    /// home, where sitemaps are deliberately not fetched (see the `.task` below).
    @State private var settingsSitemapForWatchLabel = ""
    @State private var settingsSitemapForCarPlay = ""
    @State private var settingsDisableRemoteConnection = false
    @State private var settingsAvatarImagePath: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarDisplayImage: Image?
    @State private var showPhotoPicker = false
    @State private var cropSource: CropSource?
    @State private var pendingCroppedImage: UIImage?
    @State private var showAvatarPicker = false
    @State private var showColorPickerRow = false
    @State private var settingsAvatarColor: String?
    @State private var settingsAvatarIconName: String?
    @State private var iconRowPinWidth: CGFloat = 44
    @State private var colorRowPinWidth: CGFloat = 44

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
    @State private var currentActiveHomeId: UUID?

    @Environment(\.self) private var environment
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
        var sitemapForCarPlay: String
        var localConnectionConfig: ConnectionConfiguration
        var remoteConnectionConfig: ConnectionConfiguration
        var sseCommandItem: String
        var homeName: String
        var disableRemoteConnection: Bool
        var avatarImagePath: String?
        var avatarColor: String?
        var avatarIconName: String?
        var hasPendingCrop: Bool
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
            sitemapForCarPlay: settingsSitemapForCarPlay,
            localConnectionConfig: settingsLocalConnectionConfiguration,
            remoteConnectionConfig: settingsRemoteConnectionConfiguration,
            sseCommandItem: settingsSSECommandItem,
            homeName: settingsHomeName,
            disableRemoteConnection: settingsDisableRemoteConnection,
            avatarImagePath: settingsAvatarImagePath,
            avatarColor: settingsAvatarColor,
            avatarIconName: settingsAvatarIconName,
            hasPendingCrop: pendingCroppedImage != nil
        )
    }

    var body: some View {
        Form {
            homeIdentitySection

            ConnectionSettingsView(
                settingsDemomode: $settingsDemomode,
                localConnectionConfiguration: $settingsLocalConnectionConfiguration,
                remoteConnectionConfiguration: $settingsRemoteConnectionConfiguration,
                localTestedOKURL: $localTestedOKURL,
                disableRemoteConnection: $settingsDisableRemoteConnection
            )

            commandItemSection

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
                settingsSitemapForCarPlay: $settingsSitemapForCarPlay,
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
        .interactiveDismissDisabled(isDirty)
        .navigationTitle("Home Settings")
        .alert("Local Network Access Required", isPresented: $showLocalNetworkAlert) {
            Button("Open Settings") {
                commitSave()
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
                dismiss()
            }
            Button("OK") {
                commitSave()
                dismiss()
            }
        } message: {
            Text("To connect to your local openHAB server, please allow Local Network access when prompted. If you previously denied it, enable it in Settings → Privacy & Security → Local Network.")
        }
        .toolbar { settingsToolbar }
        .onDisappear(perform: handleSwipeDismiss)
        .onChange(of: currentSnapshot) { _, newSnapshot in
            isDirty = newSnapshot != initialSnapshot
        }
        .task {
            guard !viewAppearedOnce else { return }
            viewAppearedOnce = true
            currentActiveHomeId = await Preferences.shared.currentHomePreferences.id
            await loadSettings()
            initialSnapshot = currentSnapshot
            if let initialValues {
                applySnapshot(initialValues)
            }
        }
        .task(id: networkTracker.activeConnection) {
            // Sitemaps are only fetchable via the live active connection. For an
            // inactive home being edited, leave `sitemaps` empty so the "Sitemap for
            // Apple Watch" picker disables itself rather than showing/saving choices
            // from a different home's server.
            let activeHomeId = await Preferences.shared.currentHomePreferences.id
            guard homeId == nil || homeId == activeHomeId,
                  let activeConnection = networkTracker.activeConnection
            else { return }
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
        .fullScreenCover(item: $cropSource) { source in
            let targetId = homeId ?? currentActiveHomeId ?? UUID()
            let bgHex = settingsAvatarColor ?? HomeAvatarView.colorPalette[0]
            let onConfirm: (UIImage) -> Void = { cropped in
                cropSource = nil
                selectedPhoto = nil
                // Hold in memory — written to disk only when the user taps the checkmark.
                pendingCroppedImage = cropped
                avatarDisplayImage = Image(uiImage: cropped)
                settingsAvatarImagePath = AvatarImageHelper.avatarURL(for: targetId).path
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAvatarPicker = false
                    showColorPickerRow = false
                }
            }
            let onCancel: () -> Void = {
                cropSource = nil
                selectedPhoto = nil
            }
            switch source.kind {
            case .photoItem(let item):
                CropImageView(photoItem: item, initialBackgroundHex: bgHex, onConfirm: onConfirm, onCancel: onCancel)
            case .uiImage(let uiImage):
                CropImageView(image: uiImage, initialBackgroundHex: bgHex, onConfirm: onConfirm, onCancel: onCancel)
            }
        }
    }

    // MARK: - Home identity section (avatar + name + icon/color)

    private var homeIdentitySection: some View {
        Section {
            HStack(spacing: 16) {
                avatarPickerButton
                TextField("Home name", text: $settingsHomeName)
                    .font(.headline)
            }
            .padding(.vertical, 4)

            if showAvatarPicker {
                iconPickerRow
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if showAvatarPicker && showColorPickerRow {
                colorPickerRow
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var avatarPickerButton: some View {
        let displayImage = avatarDisplayImage
        let iconName = settingsAvatarIconName ?? HomeAvatarView.defaultIconName
        let avatarColor = Color(hex: settingsAvatarColor ?? "") ?? HomeAvatarView.defaultColor
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if showAvatarPicker {
                    showAvatarPicker = false
                    showColorPickerRow = false
                } else {
                    showAvatarPicker = true
                    // If the avatar is currently showing an icon (no loaded photo), pre-open
                    // the color row so the user lands with both rows visible immediately.
                    // Also ensure the icon name is explicit so the selection ring is visible.
                    if avatarDisplayImage == nil {
                        // loadSettings() found no photo file, so any stored path is stale.
                        // Clear it so hasPhoto evaluates correctly in the icon picker.
                        settingsAvatarImagePath = nil
                        if settingsAvatarIconName == nil {
                            settingsAvatarIconName = HomeAvatarView.defaultIconName
                        }
                        showColorPickerRow = true
                    }
                }
            }
        } label: {
            HomeAvatarView(photo: displayImage, iconName: iconName, color: avatarColor, size: 72)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: showAvatarPicker ? "checkmark.circle.fill" : "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .blue)
                        .animation(.easeInOut(duration: 0.15), value: showAvatarPicker)
                }
        }
        .buttonStyle(.plain)
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images, photoLibrary: .shared())
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            cropSource = CropSource(kind: .photoItem(item))
        }
    }

    private var iconPickerRow: some View {
        let hasPhoto = avatarDisplayImage != nil || settingsAvatarImagePath != nil
        let tint = Color(hex: settingsAvatarColor ?? "") ?? HomeAvatarView.defaultColor
        let pinLeading: CGFloat = 8
        let gap: CGFloat = 10 // matches icon HStack spacing
        return ZStack(alignment: .leading) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(HomeAvatarView.availableIcons, id: \.self) { icon in
                        let isSelected = !hasPhoto && (settingsAvatarIconName ?? HomeAvatarView.defaultIconName) == icon
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settingsAvatarIconName = icon
                                // Clear display state only — file stays on disk so the
                                // photo button can re-open crop without going to the gallery.
                                avatarDisplayImage = nil
                                pendingCroppedImage = nil
                                settingsAvatarImagePath = nil
                                showColorPickerRow = true
                            }
                        } label: {
                            ZStack {
                                Circle().fill(isSelected ? tint.circleFillColor(in: environment) : tint.iconForegroundColor(in: environment))
                                Image(systemName: icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(isSelected ? tint.iconForegroundColor(in: environment) : tint.circleFillColor(in: environment))
                            }
                            .frame(width: 40, height: 40)
                            .overlay {
                                if isSelected { Circle().strokeBorder(.blue, lineWidth: 2) }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                // inset derived from measured button width — adapts to glass size on iOS 26
                .padding(.leading, pinLeading + iconRowPinWidth + gap)
                .padding(.trailing, 32)
                .padding(.vertical, 4)
            }
            .overlay(alignment: .trailing) {
                LinearGradient(
                    colors: [.clear, Color(uiColor: .secondarySystemGroupedBackground)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 32)
                .allowsHitTesting(false)
            }

            leadingFadeGradient(
                width: pinLeading + iconRowPinWidth + 20,
                opaqueColor: Color(uiColor: .secondarySystemGroupedBackground)
            )

            iconRowPhotoButton(hasPhoto: hasPhoto)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { iconRowPinWidth = $0 }
                .padding(.leading, pinLeading)
        }
    }

    @ViewBuilder
    private func iconRowPhotoButton(hasPhoto: Bool) -> some View {
        let targetId = homeId ?? currentActiveHomeId ?? UUID()
        let openAction: () -> Void = {
            // Prefer the in-memory pending crop; fall back to the file on disk (kept even
            // when the user switches to an icon so they can recrop without re-picking).
            if let pending = pendingCroppedImage {
                cropSource = CropSource(kind: .uiImage(pending))
            } else if let uiImage = UIImage(contentsOfFile: AvatarImageHelper.avatarURL(for: targetId).path) {
                cropSource = CropSource(kind: .uiImage(uiImage))
            } else {
                showPhotoPicker = true
            }
        }
        if #available(iOS 26, *) {
            Button(action: openAction) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 16))
                    .foregroundStyle(hasPhoto ? Color.blue : Color.accentColor)
                    .frame(width: 44, height: 44)
                    .contentShape(RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 13))
        } else {
            Button(action: openAction) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(hasPhoto ? Color.blue : Color.blue.opacity(0.12))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 16))
                            .foregroundStyle(hasPhoto ? .white : .blue)
                    }
                    .overlay {
                        if hasPhoto { RoundedRectangle(cornerRadius: 8).strokeBorder(.blue, lineWidth: 2) }
                    }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var settingsColorPicker: some View {
        // 44×44 frame extends UIColorWell's touch area to fill the glass shape.
        let base = ColorPicker("", selection: Binding(
            get: { Color(hex: settingsAvatarColor ?? HomeAvatarView.colorPalette[0]) ?? HomeAvatarView.defaultColor },
            set: { settingsAvatarColor = $0.hexString }
        ), supportsOpacity: false)
        .labelsHidden()
        .frame(width: 44, height: 44)
        .contentShape(RoundedRectangle(cornerRadius: 13))
        if #available(iOS 26, *) {
            base.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 13))
        } else {
            base
        }
    }

    private var colorPickerRow: some View {
        let pinLeading: CGFloat = 8
        let gap: CGFloat = 8 // matches swatch HStack spacing
        return ZStack(alignment: .leading) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HomeAvatarView.colorPalette, id: \.self) { hex in
                        let color = Color(hex: hex) ?? .blue
                        let isSelected = settingsAvatarColor == hex
                        Button {
                            settingsAvatarColor = hex
                        } label: {
                            Circle()
                                .fill(color)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if isSelected {
                                        Circle().strokeBorder(.white, lineWidth: 2.5)
                                    }
                                }
                                .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                // inset derived from measured picker width — adapts to glass size on iOS 26
                .padding(.leading, pinLeading + colorRowPinWidth + gap)
                .padding(.trailing, 32)
                .padding(.vertical, 4)
            }
            .overlay(alignment: .trailing) {
                LinearGradient(
                    colors: [.clear, Color(uiColor: .secondarySystemGroupedBackground)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 32)
                .allowsHitTesting(false)
            }

            leadingFadeGradient(
                width: pinLeading + colorRowPinWidth + 20,
                opaqueColor: Color(uiColor: .secondarySystemGroupedBackground)
            )

            settingsColorPicker
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { colorRowPinWidth = $0 }
                .padding(.leading, pinLeading)
        }
    }

    /// Fades from `opaqueColor` to transparent, masking scroll content as it passes
    /// under the pinned leading item. Glass on the pinned item is translucent, so
    /// content scrolling behind it would cut off abruptly without this gradient.
    private func leadingFadeGradient(width: CGFloat, opaqueColor: Color) -> some View {
        LinearGradient(
            colors: [opaqueColor, opaqueColor.opacity(0)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: width)
        .allowsHitTesting(false)
    }

    private var commandItemLabelText: String {
        guard let selectedSSEItemName, !selectedSSEItemName.isEmpty else {
            return "Command Item "
        }
        return "Command Item (\(selectedSSEItemName))"
    }

    @ViewBuilder
    private var commandItemSection: some View {
        Section(footer: Text(String(localized: "command_item_footer"))) {
            NavigationLink {
                ItemSelectionView(selectedItemName: $selectedSSEItemName)
            } label: {
                HStack {
                    Text(commandItemLabelText)
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
        .onChange(of: selectedSSEItemName) { _, newSelection in
            settingsSSECommandItem = newSelection ?? ""
        }
        .onAppear {
            selectedSSEItemName = settingsSSECommandItem
        }
    }

    @ToolbarContentBuilder
    private var settingsToolbar: some ToolbarContent {
        if isDirty {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: handleResetTapped) {
                    Image(systemName: "arrow.counterclockwise")
                }
                Button(action: handleSaveTapped) {
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

    private func handleResetTapped() {
        guard let snapshot = initialSnapshot else { return }
        pendingCroppedImage = nil
        let targetId = homeId ?? currentActiveHomeId ?? UUID()
        avatarDisplayImage = AvatarImageHelper.load(for: targetId)
        applySnapshot(snapshot)
    }

    private func handleSaveTapped() {
        savedExplicitly = true
        // Persisting settings reactively kicks off a real connection attempt to the new local
        // URL (NetworkConnectionService, 500ms debounced) — which, for a self-signed local
        // server, triggers the certificate-trust alert. Showing that heads-up first and
        // deferring the actual save until it's acknowledged avoids the two alerts racing
        // (the local-network one would otherwise flash and immediately get covered).
        if !settingsDemomode,
           !settingsLocalConnectionConfiguration.url.isEmpty,
           settingsLocalConnectionConfiguration.url != loadedLocalURL,
           settingsLocalConnectionConfiguration.url != localTestedOKURL {
            showLocalNetworkAlert = true
        } else {
            commitSave()
            dismiss()
        }
    }

    private func commitSave() {
        let targetId = homeId ?? currentActiveHomeId ?? UUID()
        if let pending = pendingCroppedImage {
            // Flush the in-memory crop to disk now that the user has confirmed.
            if let data = pending.jpegData(compressionQuality: 0.9) {
                AvatarImageHelper.save(data, for: targetId)
            }
            pendingCroppedImage = nil
        } else if settingsAvatarImagePath == nil, initialSnapshot?.avatarImagePath != nil {
            // User switched from photo to icon — remove the old file.
            AvatarImageHelper.delete(for: targetId)
        }
        Task { @MainActor in
            await saveSettings()
            NotificationCenter.default.post(name: NSNotification.Name("org.openhab.preferences.saved"), object: nil)
        }
    }

    private func handleSwipeDismiss() {
        guard isDirty, !savedExplicitly else { return }
        // Sheet was swiped away with unsaved changes — capture values and notify parent
        let dm = settingsDemomode, rts = settingsRealTimeSliders
        let it = settingsIconType, ssb = settingsSortSitemapsBy
        let sdm = settingsSitemapNameLabelDisplayMode
        let dmu = settingsDefaultMainUIPath, aawrtc = settingsAlwaysAllowWebRTC
        let sfw = settingsSitemapForWatch
        let sfwLabel = sitemaps.first { $0.name == sfw }?.label ?? settingsSitemapForWatchLabel
        let sfc = settingsSitemapForCarPlay
        let lcc = settingsLocalConnectionConfiguration
        let rcc = settingsRemoteConnectionConfiguration
        let sseCI = settingsSSECommandItem
        let hn = settingsHomeName
        let drc = settingsDisableRemoteConnection
        let aip = settingsAvatarImagePath
        let ac = settingsAvatarColor
        let ain = settingsAvatarIconName
        let capturedHomeId = homeId
        let snapshot = currentSnapshot
        onDismissedDirty?(snapshot) {
            Task {
                let targetId: UUID
                if let id = capturedHomeId {
                    targetId = id
                } else {
                    targetId = (await Preferences.shared.currentHomePreferences).id
                }
                await Preferences.shared.modifyStoredHome(targetId) { prefs in
                    prefs.demomode = dm
                    prefs.realTimeSliders = rts
                    prefs.iconType = it.rawValue
                    prefs.sortSitemapsBy = ssb.rawValue
                    prefs.sitemapNameLabelDisplayMode = sdm
                    prefs.defaultMainUIPath = dmu
                    prefs.alwaysAllowWebRTC = aawrtc
                    prefs.sitemapForWatch = sfw
                    prefs.sitemapForWatchLabel = sfwLabel
                    prefs.sitemapForCarPlay = sfc
                    prefs.localConnectionConfig = lcc
                    prefs.remoteConnectionConfig = rcc
                    prefs.sseCommandItem = sseCI
                    prefs.homeName = hn
                    prefs.disableRemoteConnection = drc
                    prefs.avatarImagePath = aip
                    prefs.avatarColor = ac
                    prefs.avatarIconName = ain
                }
                NotificationCenter.default.post(name: NSNotification.Name("org.openhab.preferences.saved"), object: nil)
            }
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
            let sortSitemapsBy = (await Preferences.shared.currentHomePreferences).sortSitemapsBy
            switch SortSitemapsOrder(rawValue: sortSitemapsBy) ?? .label {
            case .label: sitemaps.sort { $0.label < $1.label }
            case .name: sitemaps.sort { $0.name < $1.name }
            }
        } catch {
            Logger.settingsView.error("\(error.localizedDescription)")
            sitemaps = []
        }
    }

    private func loadSettings() async {
        #if !DEBUG
        Logger.settingsView.debug("Loading Settings")
        #endif
        let homePrefs: HomePreferences
        if let homeId, let stored = await Preferences.shared.storedHomeWithCredentials(forId: homeId) {
            homePrefs = stored
        } else {
            homePrefs = await Preferences.shared.currentHomePreferences
        }
        settingsDemomode = homePrefs.demomode
        settingsRealTimeSliders = homePrefs.realTimeSliders
        settingsIconType = IconType(rawValue: homePrefs.iconType) ?? .svg
        settingsSortSitemapsBy = SortSitemapsOrder(rawValue: homePrefs.sortSitemapsBy) ?? .label
        settingsSitemapNameLabelDisplayMode = homePrefs.sitemapNameLabelDisplayMode
        settingsDefaultMainUIPath = homePrefs.defaultMainUIPath
        settingsAlwaysAllowWebRTC = homePrefs.alwaysAllowWebRTC
        settingsSitemapForWatch = homePrefs.sitemapForWatch
        settingsSitemapForWatchLabel = homePrefs.sitemapForWatchLabel
        settingsSitemapForCarPlay = homePrefs.sitemapForCarPlay
        settingsLocalConnectionConfiguration = homePrefs.localConnectionConfig
        settingsRemoteConnectionConfiguration = homePrefs.remoteConnectionConfig
        loadedLocalURL = homePrefs.localConnectionConfig.url
        settingsHomeName = homePrefs.homeName
        settingsSSECommandItem = homePrefs.sseCommandItem
        settingsDisableRemoteConnection = homePrefs.disableRemoteConnection
        settingsAvatarImagePath = homePrefs.avatarImagePath
        settingsAvatarColor = homePrefs.avatarColor
        settingsAvatarIconName = homePrefs.avatarIconName
        avatarDisplayImage = AvatarImageHelper.load(for: homePrefs.id)
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
        settingsSitemapForCarPlay = snapshot.sitemapForCarPlay
        settingsLocalConnectionConfiguration = snapshot.localConnectionConfig
        settingsRemoteConnectionConfiguration = snapshot.remoteConnectionConfig
        settingsSSECommandItem = snapshot.sseCommandItem
        settingsHomeName = snapshot.homeName
        settingsDisableRemoteConnection = snapshot.disableRemoteConnection
        settingsAvatarImagePath = snapshot.avatarImagePath
        settingsAvatarColor = snapshot.avatarColor
        settingsAvatarIconName = snapshot.avatarIconName
    }

    func saveSettings() async {
        let sitemapLabel = sitemaps.first { $0.name == settingsSitemapForWatch }?.label ?? settingsSitemapForWatchLabel
        let capturedHomeId = homeId
        let dm = settingsDemomode, rts = settingsRealTimeSliders
        let it = settingsIconType, ssb = settingsSortSitemapsBy
        let sdm = settingsSitemapNameLabelDisplayMode
        let dmu = settingsDefaultMainUIPath, aawrtc = settingsAlwaysAllowWebRTC
        let sfw = settingsSitemapForWatch
        let sfc = settingsSitemapForCarPlay
        let lcc = settingsLocalConnectionConfiguration
        let rcc = settingsRemoteConnectionConfiguration
        let sseCI = settingsSSECommandItem
        let hn = settingsHomeName
        let drc = settingsDisableRemoteConnection
        let aip = settingsAvatarImagePath
        let ac = settingsAvatarColor
        let ain = settingsAvatarIconName
        let targetId: UUID
        if let id = capturedHomeId {
            targetId = id
        } else {
            targetId = (await Preferences.shared.currentHomePreferences).id
        }
        await Preferences.shared.modifyStoredHome(targetId) { homePreferences in
            homePreferences.demomode = dm
            homePreferences.realTimeSliders = rts
            homePreferences.iconType = it.rawValue
            homePreferences.sortSitemapsBy = ssb.rawValue
            homePreferences.sitemapNameLabelDisplayMode = sdm
            homePreferences.defaultMainUIPath = dmu
            homePreferences.alwaysAllowWebRTC = aawrtc
            homePreferences.sitemapForWatch = sfw
            homePreferences.sitemapForWatchLabel = sitemapLabel
            homePreferences.sitemapForCarPlay = sfc
            homePreferences.localConnectionConfig = lcc
            homePreferences.remoteConnectionConfig = rcc
            homePreferences.sseCommandItem = sseCI
            homePreferences.homeName = hn
            homePreferences.disableRemoteConnection = drc
            homePreferences.avatarImagePath = aip
            homePreferences.avatarColor = ac
            homePreferences.avatarIconName = ain
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
