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

struct HomeSettingsView: View, SettingsSheetView {
    var networkTracker = MainActorNetworkTracker.shared
    /// When non-nil, the view edits the specified stored home instead of the active home.
    var homeId: UUID?

    var initialValues: SettingsSnapshot?

    // MARK: — Tracked settings state
    @State var current = SettingsSnapshot()
    @State var initial = SettingsSnapshot()

    // MARK: — Avatar / photo state (not part of dirty tracking)
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarDisplayImage: Image?
    @State private var showPhotoPicker = false
    @State private var cropSource: CropSource?
    /// Full-resolution original held in memory until save; written to disk only in `commitSave()`.
    @State private var pendingOriginalImage: UIImage?
    @State private var showAvatarPicker = false
    @State private var showColorPickerRow = false
    @State private var iconRowPinWidth: CGFloat = 44
    @State private var colorRowPinWidth: CGFloat = 44

    // MARK: — Auxiliary state
    @State private var sitemaps: [OpenHABSitemap] = []
    @State private var sitemapForWatchLabel = ""
    @State private var viewAppearedOnce = false
    @State private var showLocalNetworkAlert = false
    @State private var loadedLocalURL = ""
    @State private var localTestedOKURL = ""
    @State private var selectedSSEItemName: String?
    @State private var showAppSettings = false
    @State private var showCommandItemInfo = false
    @State private var currentActiveHomeId: UUID?

    @Environment(\.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    struct SettingsSnapshot: Equatable {
        var demomode: Bool = false
        var realTimeSliders: Bool = true
        var iconType: IconType = .svg
        var sortSitemapsBy: SortSitemapsOrder = .label
        var sitemapNameLabelDisplayMode: SitemapNameLabelDisplayMode = .label
        var defaultMainUIPath: String = ""
        var alwaysAllowWebRTC: Bool = true
        var sitemapForWatch: String = ""
        var sitemapForCarPlay: String = ""
        var localConnectionConfig: ConnectionConfiguration = ConnectionConfiguration(url: "", username: "", password: "")
        var remoteConnectionConfig: ConnectionConfiguration = ConnectionConfiguration(url: "", username: "", password: "")
        var sseCommandItem: String = ""
        var homeName: String = ""
        var disableRemoteConnection: Bool = false
        /// `nil` means "use default icon". Changes here drive `isDirty`.
        var avatarMode: AvatarMode?
        var sectionOrder: [MenuSection] = MenuSection.allCases
        var collapsedSections: Set<MenuSection> = []
    }

    private var hiddenSections: [MenuSection] {
        let visible = Set(current.sectionOrder)
        return MenuSection.allCases.filter { !visible.contains($0) }
    }

    var body: some View {
        Form {
            homeIdentitySection

            ConnectionSettingsView(
                settingsDemomode: $current.demomode,
                localConnectionConfiguration: $current.localConnectionConfig,
                remoteConnectionConfiguration: $current.remoteConnectionConfig,
                localTestedOKURL: $localTestedOKURL,
                disableRemoteConnection: $current.disableRemoteConnection
            )

            commandItemSection

            MainUISettingsView(
                settingsAlwaysAllowWebRTC: $current.alwaysAllowWebRTC,
                settingsDefaultMainUIPath: $current.defaultMainUIPath
            )

            SitemapSettingsView(
                settingsRealTimeSliders: $current.realTimeSliders,
                settingsIconType: $current.iconType,
                settingsSortSitemapsBy: $current.sortSitemapsBy,
                settingsSitemapNameLabelDisplayMode: $current.sitemapNameLabelDisplayMode,
                settingsSitemapForWatch: $current.sitemapForWatch,
                settingsSitemapForCarPlay: $current.sitemapForCarPlay,
                sitemaps: $sitemaps
            )

            Section(header: Text("Menu Sections")) {
                ForEach(current.sectionOrder, id: \.self) { section in
                    inlineSectionRow(section, isVisible: true)
                        .id("v-\(section.rawValue)")
                }
                .onMove { source, destination in
                    current.sectionOrder.move(fromOffsets: source, toOffset: destination)
                }
                ForEach(hiddenSections, id: \.self) { section in
                    inlineSectionRow(section, isVisible: false)
                        .moveDisabled(true)
                        .id("h-\(section.rawValue)")
                }
            }

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
        .environment(\.editMode, .constant(.active))
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
        .settingsSheet(from: self)
        .task {
            guard !viewAppearedOnce else { return }
            viewAppearedOnce = true
            currentActiveHomeId = await Preferences.shared.currentHomePreferences.id
            let homePrefs: HomePreferences
            if let homeId, let stored = await Preferences.shared.storedHomeWithCredentials(forId: homeId) {
                homePrefs = stored
            } else {
                homePrefs = await Preferences.shared.currentHomePreferences
            }
            current = SettingsSnapshot(from: homePrefs)
            sitemapForWatchLabel = homePrefs.sitemapForWatchLabel
            avatarDisplayImage = AvatarImageHelper.renderedAvatar(for: homePrefs.id, mode: homePrefs.avatarMode)
            loadedLocalURL = homePrefs.localConnectionConfig.url
            initial = current
            if let initialValues {
                current = initialValues
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
            let onConfirm: (UIImage, AvatarMode) -> Void = { original, mode in
                cropSource = nil
                selectedPhoto = nil
                // Hold original in memory — written to disk only when the user taps checkmark.
                pendingOriginalImage = original
                avatarDisplayImage = AvatarImageHelper.renderPending(original, mode: mode)
                current.avatarMode = mode
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
                CropImageView(photoItem: item, onConfirm: onConfirm, onCancel: onCancel)
            case .uiImage(let uiImage):
                CropImageView(image: uiImage, initialMode: current.avatarMode, onConfirm: onConfirm, onCancel: onCancel)
            }
        }
    }

    // MARK: - Home identity section (avatar + name + icon/color)

    private var homeIdentitySection: some View {
        Section {
            HStack(spacing: 16) {
                avatarPickerButton
                TextField("Home name", text: $current.homeName)
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
        let iconName = current.avatarMode?.iconName ?? HomeAvatarView.defaultIconName
        let avatarColor = Color(hex: current.avatarMode?.colorHex ?? "") ?? HomeAvatarView.defaultColor
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if showAvatarPicker {
                    showAvatarPicker = false
                    showColorPickerRow = false
                } else {
                    showAvatarPicker = true
                    // If no photo is displayed, open the color row immediately so the
                    // user lands with icon + color rows both visible. Don't mutate
                    // current.avatarMode here — that would make the form look dirty.
                    if avatarDisplayImage == nil {
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
        let hasPhoto: Bool = { if case .image = current.avatarMode { return true } else { return false } }()
        let tint = Color(hex: current.avatarMode?.colorHex ?? "") ?? HomeAvatarView.defaultColor
        let pinLeading: CGFloat = 8
        let gap: CGFloat = 10 // matches icon HStack spacing
        return ZStack(alignment: .leading) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(HomeAvatarView.availableIcons, id: \.self) { icon in
                        let isSelected = !hasPhoto && (current.avatarMode?.iconName ?? HomeAvatarView.defaultIconName) == icon
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                let color = current.avatarMode?.colorHex ?? HomeAvatarView.colorPalette[0]
                                current.avatarMode = .icon(name: icon, color: color)
                                // Clear display state — the original stays on disk so the
                                // photo button can re-open crop without going to the gallery.
                                avatarDisplayImage = nil
                                pendingOriginalImage = nil
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
            // Prefer the in-memory pending original; fall back to the original on disk (kept
            // even when the user switches to an icon so they can recrop without re-picking).
            if let pending = pendingOriginalImage {
                cropSource = CropSource(kind: .uiImage(pending))
            } else if let original = AvatarImageHelper.loadOriginal(for: targetId) {
                cropSource = CropSource(kind: .uiImage(original))
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
            get: { Color(hex: current.avatarMode?.colorHex ?? HomeAvatarView.colorPalette[0]) ?? HomeAvatarView.defaultColor },
            set: { current.avatarMode = (current.avatarMode ?? .icon(name: HomeAvatarView.defaultIconName, color: "")).withColor($0.hexString) }
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
                        let isSelected = current.avatarMode?.colorHex == hex
                        Button {
                            current.avatarMode = (current.avatarMode ?? .icon(name: HomeAvatarView.defaultIconName, color: "")).withColor(hex)
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
            current.sseCommandItem = newSelection ?? ""
        }
        .onAppear {
            selectedSSEItemName = current.sseCommandItem
        }
    }

    @ViewBuilder
    private func inlineSectionRow(_ section: MenuSection, isVisible: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation {
                    if isVisible {
                        current.sectionOrder.removeAll { $0 == section }
                    } else {
                        current.sectionOrder.append(section)
                    }
                }
            } label: {
                Image(systemName: isVisible ? "eye.fill" : "eye.slash")
                    .foregroundStyle(isVisible ? Color.accentColor : Color.secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if current.collapsedSections.contains(section) {
                        current.collapsedSections.remove(section)
                    } else {
                        current.collapsedSections.insert(section)
                    }
                }
            } label: {
                Image(systemName: "chevron.down.circle")
                    .rotationEffect(.degrees(current.collapsedSections.contains(section) ? -90 : 0))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }
            .buttonStyle(.plain)

            Text(section.displayName)
        }
        .frame(minHeight: 44)
    }

    func onRevert() {
        pendingOriginalImage = nil
        let targetId = homeId ?? currentActiveHomeId ?? UUID()
        avatarDisplayImage = AvatarImageHelper.renderedAvatar(for: targetId, mode: initial.avatarMode)
        current = initial
    }

    func onCancel() {
        dismiss()
    }

    func onSave() {
        // Persisting settings reactively kicks off a real connection attempt to the new local
        // URL (NetworkConnectionService, 500ms debounced) — which, for a self-signed local
        // server, triggers the certificate-trust alert. Showing that heads-up first and
        // deferring the actual save until it's acknowledged avoids the two alerts racing
        // (the local-network one would otherwise flash and immediately get covered).
        if !current.demomode,
           !current.localConnectionConfig.url.isEmpty,
           current.localConnectionConfig.url != loadedLocalURL,
           current.localConnectionConfig.url != localTestedOKURL {
            showLocalNetworkAlert = true
        } else {
            commitSave()
            dismiss()
        }
    }

    private func commitSave() {
        let targetId = homeId ?? currentActiveHomeId ?? UUID()
        if let pending = pendingOriginalImage {
            // Flush the in-memory original to disk now that the user has confirmed.
            AvatarImageHelper.saveOriginal(pending, for: targetId)
            pendingOriginalImage = nil
        } else if case .icon = current.avatarMode, case .image = initial.avatarMode {
            // User switched from photo to icon — remove the stored original.
            AvatarImageHelper.deleteOriginal(for: targetId)
        } else if current.avatarMode == nil, case .image = initial.avatarMode {
            AvatarImageHelper.deleteOriginal(for: targetId)
        }
        Task { @MainActor in
            await saveSettings()
            NotificationCenter.default.post(name: NSNotification.Name("org.openhab.preferences.saved"), object: nil)
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

    private func saveSettings() async {
        let snapshot = current
        let sitemapLabel = sitemaps.first { $0.name == snapshot.sitemapForWatch }?.label ?? sitemapForWatchLabel
        let capturedHomeId = homeId
        let targetId: UUID
        if let id = capturedHomeId {
            targetId = id
        } else {
            targetId = (await Preferences.shared.currentHomePreferences).id
        }
        await Preferences.shared.modifyStoredHome(targetId) { homePreferences in
            homePreferences.demomode = snapshot.demomode
            homePreferences.realTimeSliders = snapshot.realTimeSliders
            homePreferences.iconType = snapshot.iconType.rawValue
            homePreferences.sortSitemapsBy = snapshot.sortSitemapsBy.rawValue
            homePreferences.sitemapNameLabelDisplayMode = snapshot.sitemapNameLabelDisplayMode
            homePreferences.defaultMainUIPath = snapshot.defaultMainUIPath
            homePreferences.alwaysAllowWebRTC = snapshot.alwaysAllowWebRTC
            homePreferences.sitemapForWatch = snapshot.sitemapForWatch
            homePreferences.sitemapForWatchLabel = sitemapLabel
            homePreferences.sitemapForCarPlay = snapshot.sitemapForCarPlay
            homePreferences.localConnectionConfig = snapshot.localConnectionConfig
            homePreferences.remoteConnectionConfig = snapshot.remoteConnectionConfig
            homePreferences.sseCommandItem = snapshot.sseCommandItem
            homePreferences.homeName = snapshot.homeName
            homePreferences.disableRemoteConnection = snapshot.disableRemoteConnection
            homePreferences.avatarMode = snapshot.avatarMode
            homePreferences.sectionOrder = snapshot.sectionOrder
            homePreferences.collapsedSections = snapshot.collapsedSections
        }
    }
}

extension HomeSettingsView.SettingsSnapshot {
    /// Populates a snapshot from a `HomePreferences` value (synchronous — prefs are already fetched).
    init(from homePrefs: HomePreferences) {
        demomode = homePrefs.demomode
        realTimeSliders = homePrefs.realTimeSliders
        iconType = IconType(rawValue: homePrefs.iconType) ?? .svg
        sortSitemapsBy = SortSitemapsOrder(rawValue: homePrefs.sortSitemapsBy) ?? .label
        sitemapNameLabelDisplayMode = homePrefs.sitemapNameLabelDisplayMode
        defaultMainUIPath = homePrefs.defaultMainUIPath
        alwaysAllowWebRTC = homePrefs.alwaysAllowWebRTC
        sitemapForWatch = homePrefs.sitemapForWatch
        sitemapForCarPlay = homePrefs.sitemapForCarPlay
        localConnectionConfig = homePrefs.localConnectionConfig
        remoteConnectionConfig = homePrefs.remoteConnectionConfig
        sseCommandItem = homePrefs.sseCommandItem
        homeName = homePrefs.homeName
        disableRemoteConnection = homePrefs.disableRemoteConnection
        avatarMode = homePrefs.avatarMode
        sectionOrder = homePrefs.sectionOrder
        collapsedSections = homePrefs.collapsedSections
    }
}

extension MenuSection {
    var displayName: String {
        switch self {
        case .mainUI: return String(localized: "Main UI")
        case .sitemaps: return String(localized: "Sitemaps")
        case .tiles: return String(localized: "Tiles")
        case .system: return String(localized: "System & App")
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
