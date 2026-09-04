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

@preconcurrency import Combine
import os.log

@propertyWrapper
public struct UserDefault<T: Sendable> {
    private let key: String
    private let defaultValue: T
    private let isHomeProperty: Bool
    private let subject: CurrentValueSubject<T, Never>
    private let defaults: UserDefaults

    public var wrappedValue: T {
        get {
            let preferenceValue = defaults.object(forKey: key)
            if let converted = preferenceValue as? T {
                return converted
            }
            if let preferenceValue {
                Logger.preferences.error("Preference value \(key) was \(String(describing: preferenceValue)) but did not conform to \(T.self). Replace with default value.")
            } else {
                Logger.preferences.info("Preference value \(key) was set for the first time. Using default value.")
            }
            defaults.set(defaultValue, forKey: key)
            return defaultValue
        }
        set {
            let prefKey = key
            Logger.preferences.debug("Preference \(prefKey) will be changed to value \(String(describing: newValue), privacy: .private)")
            defaults.set(newValue, forKey: key)
            subject.send(newValue)
        }
    }

    public var projectedValue: AnyPublisher<T, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(_ key: String, defaultValue: T, isHomeProperty: Bool = false) {
        self.key = key
        self.defaultValue = defaultValue
        self.isHomeProperty = isHomeProperty
        let d = UserDefaults(suiteName: "group.org.openhab.app")!
        self.defaults = d
        let currentValue = (d.object(forKey: key) as? T) ?? defaultValue
        subject = CurrentValueSubject(currentValue)
    }
}

@propertyWrapper
public struct UserDefaultObject<T: Codable & Sendable> {
    private let key: String
    private let defaultValue: T
    private let isHomeProperty: Bool
    private let subject: CurrentValueSubject<T, Never>
    private let defaults: UserDefaults

    public var wrappedValue: T {
        get {
            let preferenceValue = defaults.object(forKey: key)
            if let data = preferenceValue as? Data,
               let decoded = try? JSONDecoder().decode(T.self, from: data) {
                return decoded
            }
            if let preferenceValue {
                Logger.preferences.error("Preference value \(key) was \(String(describing: preferenceValue)) but did not conform to \(T.self). Replace with default value.")
            } else {
                Logger.preferences.info("Preference value \(key) was set for the first time. Using default value.")
            }
            defaults.set(try? JSONEncoder().encode(defaultValue), forKey: key)
            return defaultValue
        }
        set {
            let prefKey = key
            guard let encoded = try? JSONEncoder().encode(newValue) else {
                Logger.preferences.debug("Preference \(prefKey) conversion of new value \(String(describing: newValue), privacy: .private) failed, do not store.")
                return
            }
            Logger.preferences.debug("Preference \(prefKey) will be changed to value \(String(describing: newValue), privacy: .private)")
            defaults.set(encoded, forKey: key)
            subject.send(newValue)
        }
    }

    public var projectedValue: AnyPublisher<T, Never> {
        subject.eraseToAnyPublisher()
    }

    init(_ key: String, defaultValue: T, isHomeProperty: Bool = false) {
        self.key = key
        self.defaultValue = defaultValue
        self.isHomeProperty = isHomeProperty
        let d = UserDefaults(suiteName: "group.org.openhab.app")!
        self.defaults = d
        let currentValue: T
        if let data = d.object(forKey: key) as? Data,
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            currentValue = decoded
        } else {
            currentValue = defaultValue
        }
        subject = CurrentValueSubject(currentValue)
    }
}

public struct HomePreferences: Codable, Equatable, Sendable {
    public let id: UUID
    public var defaultView = "web"
    public var demomode = true
    public var realTimeSliders = false
    public var iconType = 0
    public var defaultSitemap = "demo"
    public var sortSitemapsBy = 0
    // Backing store for `sitemapNameLabelDisplayMode`. Optional on purpose: synthesized
    // `Codable` throws `keyNotFound` for a missing *non-optional* key (even one
    // with a default), which would discard the whole home. Optional decodes a
    // missing key as `nil`. Never read this directly — use `sitemapNameLabelDisplayMode`.
    private var sitemapNameLabelDisplayModeStorage: SitemapNameLabelDisplayMode?

    /// Which sitemap field(s) to show in menus and pickers. Resolves to the
    /// default (`.label`) when unset — both for fresh installs and for homes saved
    /// before this setting existed — so callers never have to handle `nil`.
    public var sitemapNameLabelDisplayMode: SitemapNameLabelDisplayMode {
        get { SitemapNameLabelDisplayMode.resolved(sitemapNameLabelDisplayModeStorage) }
        set { sitemapNameLabelDisplayModeStorage = newValue }
    }
    public var defaultMainUIPath = ""
    public var alwaysAllowWebRTC = false
    public var sitemapForWatch = "watch"
    public var localConnectionConfig: ConnectionConfiguration = .localDefault
    public var remoteConnectionConfig: ConnectionConfiguration = .remoteDefault
    public var sitemapForWatchLabel = "watch"
    public var homeName = "Home#1"
    public var sseCommandItem = ""
    // Toolbar menu section expansion, per home. Optional so that decoding data
    // stored before these fields existed yields `nil` (treated as expanded)
    // instead of throwing `keyNotFound` and discarding the whole home.
    public var isMainUIExpanded: Bool?
    public var isSitemapsExpanded: Bool?
    public var isTilesExpanded: Bool?
    public var isSystemExpanded: Bool?
    public var sitemapForCarPlay = ""

    // Avatar image stored as a file path, never raw Data in UserDefaults.
    // Optional so a missing key in old stored data decodes as nil (no avatar).
    public var avatarImagePath: String?
    // Hex color string and SF Symbol name for the avatar placeholder.
    // Optional so missing keys in old stored data decode as nil (use defaults).
    public var avatarColor: String?
    public var avatarIconName: String?

    // Backing store for the computed `sectionOrder` property. Optional so that
    // old stored data missing this field decodes as nil (resolves to default order).
    private var sectionOrderStorage: [MenuSection]?

    /// The display order of the toolbar menu sections for this home.
    /// Defaults to `MenuSection.allCases` when not explicitly set.
    public var sectionOrder: [MenuSection] {
        get { sectionOrderStorage ?? MenuSection.allCases }
        set { sectionOrderStorage = newValue }
    }

    // Per-section visibility. Optional so a missing key decodes as nil (visible = true).
    public var isMainUIVisible: Bool?
    public var isSitemapsVisible: Bool?
    public var isTilesVisible: Bool?
    public var isSystemVisible: Bool?

    // When true, the remote URL is excluded from data-connection attempts.
    // Independent of `supportsNotifications` (the openHAB Cloud push toggle).
    // Non-optional with `decodeIfPresent` default so existing homes keep remote enabled.
    public var disableRemoteConnection = false

    fileprivate init(id: UUID) {
        self.id = id
    }

    /// The connection configurations the network tracker uses for this home: the shared
    /// demo connection in demo mode, otherwise the local and remote connections. Two demo
    /// homes therefore resolve to the same set, which is why the tracker does not
    /// re-publish when switching between them.
    public var trackedConnections: [ConnectionConfiguration] {
        if demomode { return [.demo] }
        return disableRemoteConnection ? [localConnectionConfig] : [localConnectionConfig, remoteConnectionConfig]
    }

    /// Custom decoder so that stored data from older app versions that are missing
    /// fields added later (e.g. alwaysAllowWebRTC, defaultMainUIPath, siteMapForWatchLabel)
    /// still decodes successfully. Without this, synthesized Codable requires every field
    /// to be present and silently falls back to the struct default via `try?` in
    /// UserDefaultObject — resetting homeName to "Home#1" for those users.
    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        defaultView = try container.decodeIfPresent(String.self, forKey: .defaultView) ?? "web"
        demomode = try container.decodeIfPresent(Bool.self, forKey: .demomode) ?? true
        realTimeSliders = try container.decodeIfPresent(Bool.self, forKey: .realTimeSliders) ?? false
        iconType = try container.decodeIfPresent(Int.self, forKey: .iconType) ?? 0
        defaultSitemap = try container.decodeIfPresent(String.self, forKey: .defaultSitemap) ?? "demo"
        sortSitemapsBy = try container.decodeIfPresent(Int.self, forKey: .sortSitemapsBy) ?? 0
        defaultMainUIPath = try container.decodeIfPresent(String.self, forKey: .defaultMainUIPath) ?? ""
        alwaysAllowWebRTC = try container.decodeIfPresent(Bool.self, forKey: .alwaysAllowWebRTC) ?? false
        sitemapForWatch = try container.decodeIfPresent(String.self, forKey: .sitemapForWatch) ?? "watch"
        // Role-aware decode: supportsNotifications defaults to false for local, true for remote,
        // so legacy stored configs written before that field existed keep the correct behavior.
        localConnectionConfig = try ConnectionConfiguration.decode(from: container, forKey: .localConnectionConfig, defaultNotifications: false) ?? .localDefault
        remoteConnectionConfig = try ConnectionConfiguration.decode(from: container, forKey: .remoteConnectionConfig, defaultNotifications: true) ?? .remoteDefault
        sitemapForWatchLabel = try container.decodeIfPresent(String.self, forKey: .sitemapForWatchLabel) ?? "watch"
        homeName = try container.decodeIfPresent(String.self, forKey: .homeName) ?? "Home#1"
        sseCommandItem = try container.decodeIfPresent(String.self, forKey: .sseCommandItem) ?? ""
        // Fields added on this branch. Optional, so a missing key decodes as nil (the documented
        // "treat as unset/expanded" behavior) rather than throwing keyNotFound and discarding the home.
        sitemapNameLabelDisplayModeStorage = try container.decodeIfPresent(SitemapNameLabelDisplayMode.self, forKey: .sitemapNameLabelDisplayModeStorage)
        isMainUIExpanded = try container.decodeIfPresent(Bool.self, forKey: .isMainUIExpanded)
        isSitemapsExpanded = try container.decodeIfPresent(Bool.self, forKey: .isSitemapsExpanded)
        isTilesExpanded = try container.decodeIfPresent(Bool.self, forKey: .isTilesExpanded)
        isSystemExpanded = try container.decodeIfPresent(Bool.self, forKey: .isSystemExpanded)
        sitemapForCarPlay = try container.decodeIfPresent(String.self, forKey: .sitemapForCarPlay) ?? ""
        // Fields added for menu improvements. Optional — missing key decodes as nil.
        avatarImagePath = try container.decodeIfPresent(String.self, forKey: .avatarImagePath)
        sectionOrderStorage = try container.decodeIfPresent([MenuSection].self, forKey: .sectionOrderStorage)
        isMainUIVisible = try container.decodeIfPresent(Bool.self, forKey: .isMainUIVisible)
        isSitemapsVisible = try container.decodeIfPresent(Bool.self, forKey: .isSitemapsVisible)
        isTilesVisible = try container.decodeIfPresent(Bool.self, forKey: .isTilesVisible)
        isSystemVisible = try container.decodeIfPresent(Bool.self, forKey: .isSystemVisible)
        disableRemoteConnection = try container.decodeIfPresent(Bool.self, forKey: .disableRemoteConnection) ?? false
        avatarColor = try container.decodeIfPresent(String.self, forKey: .avatarColor)
        avatarIconName = try container.decodeIfPresent(String.self, forKey: .avatarIconName)
    }
}

public struct ApplicationPreferences: Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey {
        case showSearchField
        case sitemapDiagnosticsLogging
    }

    public var showSearchField = true
    public var sitemapDiagnosticsLogging = false

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showSearchField = try container.decodeIfPresent(Bool.self, forKey: .showSearchField) ?? true
        sitemapDiagnosticsLogging = try container.decodeIfPresent(Bool.self, forKey: .sitemapDiagnosticsLogging) ?? false
    }

    public init(showSearchField: Bool = true,
                sitemapDiagnosticsLogging: Bool = false) {
        self.showSearchField = showSearchField
        self.sitemapDiagnosticsLogging = sitemapDiagnosticsLogging
    }
}

// MARK: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

// MARK: !!

// MARK: When making changes to Preferences, always consider a migration for existing users. Otherwise, they risk to loose their existing preferences.

// MARK: !!

// MARK: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

/// Snapshot of all screensaver-related Preferences fields. Sendable, so it can cross actor boundaries.
public struct ScreenSaverPreferences: Sendable {
    public var isEnabled: Bool
    public var showsTime: Bool
    public var showsDate: Bool
    public var idleInterval: Double
    public var movementInterval: Double
    public var fontName: String
    public var timeFontSizeRatio: Double
    public var dateFontRelativeSize: Double
    public var enablesAutoDimming: Bool
    public var dimLevel: Double
    public var wakeBrightnessLevel: Double
    public var showsSeconds: Bool
    public var uses24HourTime: Bool
    public var fadeDuration: Double
    public var restoresBrightness: Bool

    public init(isEnabled: Bool, showsTime: Bool, showsDate: Bool, idleInterval: Double,
                movementInterval: Double, fontName: String, timeFontSizeRatio: Double,
                dateFontRelativeSize: Double, enablesAutoDimming: Bool, dimLevel: Double,
                wakeBrightnessLevel: Double, showsSeconds: Bool, uses24HourTime: Bool,
                fadeDuration: Double, restoresBrightness: Bool) {
        self.isEnabled = isEnabled
        self.showsTime = showsTime
        self.showsDate = showsDate
        self.idleInterval = idleInterval
        self.movementInterval = movementInterval
        self.fontName = fontName
        self.timeFontSizeRatio = timeFontSizeRatio
        self.dateFontRelativeSize = dateFontRelativeSize
        self.enablesAutoDimming = enablesAutoDimming
        self.dimLevel = dimLevel
        self.wakeBrightnessLevel = wakeBrightnessLevel
        self.showsSeconds = showsSeconds
        self.uses24HourTime = uses24HourTime
        self.fadeDuration = fadeDuration
        self.restoresBrightness = restoresBrightness
    }
}

private final class CancellableBox: @unchecked Sendable {
    var cancellable: AnyCancellable?
}

public actor Preferences {
    public static let shared = Preferences()

    private static let defaultHomeId = UUID()

    // Used by migration methods to read old keys directly from the suite.
    private let sharedDefaults = UserDefaults(suiteName: "group.org.openhab.app")!

    @UserDefaultObject("currentHomePreferences", defaultValue: HomePreferences(id: defaultHomeId))
    private var _currentHomePreferences: HomePreferences

    @UserDefault("sendCrashReports", defaultValue: false)
    public var sendCrashReports: Bool

    @UserDefault("idleOff", defaultValue: false)
    public var idleOff: Bool

    @UserDefaultObject(
        "applicationPreferences",
        defaultValue:
        ApplicationPreferences()
    )
    public private(set) var applicationPreferences: ApplicationPreferences

    @UserDefault("screensaverEnabled", defaultValue: false)
    public var screensaverEnabled: Bool

    @UserDefault("screensaverShowsTime", defaultValue: true)
    public var screensaverShowsTime: Bool

    @UserDefault("screensaverShowsDate", defaultValue: true)
    public var screensaverShowsDate: Bool

    @UserDefault("screensaverIdleInterval", defaultValue: 120.0)
    public var screensaverIdleInterval: Double

    @UserDefault("screensaverMovementInterval", defaultValue: 8.0)
    public var screensaverMovementInterval: Double

    @UserDefault("screensaverFontName", defaultValue: "")
    public var screensaverFontName: String

    @UserDefault("screensaverTimeFontRatio", defaultValue: 0.2)
    public var screensaverTimeFontRatio: Double

    @UserDefault("screensaverDateFontRatio", defaultValue: 0.4)
    public var screensaverDateFontRatio: Double

    @UserDefault("screensaverEnableDimming", defaultValue: true)
    public var screensaverEnableDimming: Bool

    @UserDefault("screensaverDimLevel", defaultValue: 0.3)
    public var screensaverDimLevel: Double

    @UserDefault("screensaverShowsSeconds", defaultValue: false)
    public var screensaverShowsSeconds: Bool

    @UserDefault("screensaverUse24Hour", defaultValue: false)
    public var screensaverUse24Hour: Bool

    @UserDefault("screensaverFadeDuration", defaultValue: 2.0)
    public var screensaverFadeDuration: Double

    @UserDefault("screensaverRestoreBrightness", defaultValue: true)
    public var screensaverRestoreBrightness: Bool

    @UserDefault("screensaverWakeBrightness", defaultValue: 1.0)
    public var screensaverWakeBrightness: Double

    @UserDefault("hideStatusBar", defaultValue: false)
    public var hideStatusBar: Bool

    @UserDefault("currentWebViewPath", defaultValue: "")
    public var currentWebViewPath: String

    /// settings for different homes
    @UserDefaultObject("homeOrder", defaultValue: [UUID]())
    public private(set) var homeOrder: [UUID]

    @UserDefaultObject("storedHomes", defaultValue: [:])
    public private(set) var storedHomes: [UUID: HomePreferences]

    /// the currently applied settings set from storedHomes
    @UserDefaultObject("activeHomeId", defaultValue: defaultHomeId)
    private var activeHomeId: UUID

    @UserDefault("didMigrateToSharedDefaults", defaultValue: false)
    private var didMigrateToSharedDefaults: Bool

    @UserDefault("didMigrateToMultipleHomes", defaultValue: false)
    private var didMigrateToMultipleHomes: Bool

    @UserDefault("didMigrateCredentialsToKeychain", defaultValue: false)
    private var didMigrateCredentialsToKeychain: Bool

    private var internalPreferenceChangeOngoing = false

    private func internalPreferenceChange(_ change: () -> Void) {
        internalPreferenceChangeOngoing = true
        change()
        internalPreferenceChangeOngoing = false
    }

    private var migrationChecked = false

    // migrationChecked is set to true BEFORE calling any migration method to prevent
    // re-entrant calls (modifyActiveHome → currentHomePreferences → ensureMigrated).
    private func ensureMigrated() {
        guard !migrationChecked else { return }
        migrationChecked = true
        initializeStoredHomes()
        migrateToSharedDefaultsIfRequired()
        migrateToMultipleHomesIfRequired()
        migrateCredentialsToKeychainIfRequired()
    }
}

// MARK: App extension access

public extension Preferences {
    static func prepareForAppExtensionAccess() async {
        _ = await Preferences.shared.listStoredHomes()
    }
}

// MARK: Credential-injecting accessors

public extension Preferences {
    /// The active home preferences with credentials injected from Keychain.
    var currentHomePreferences: HomePreferences {
        ensureMigrated()
        var prefs = _currentHomePreferences
        if let creds = CredentialsStore.retrieve(homeId: prefs.id, type: .local) {
            prefs.localConnectionConfig.username = creds.username
            prefs.localConnectionConfig.password = creds.password
        }
        if let creds = CredentialsStore.retrieve(homeId: prefs.id, type: .remote) {
            prefs.remoteConnectionConfig.username = creds.username
            prefs.remoteConnectionConfig.password = creds.password
        }
        return prefs
    }

    /// Returns a stored home's preferences with credentials injected from Keychain, or nil if not found.
    /// Mirrors what `currentHomePreferences` does for the active home, but works for any stored home UUID.
    func storedHomeWithCredentials(forId homeId: UUID) -> HomePreferences? {
        guard var home = storedHomes[homeId] else { return nil }
        if let creds = CredentialsStore.retrieve(homeId: homeId, type: .local) {
            home.localConnectionConfig.username = creds.username
            home.localConnectionConfig.password = creds.password
        }
        if let creds = CredentialsStore.retrieve(homeId: homeId, type: .remote) {
            home.remoteConnectionConfig.username = creds.username
            home.remoteConnectionConfig.password = creds.password
        }
        return home
    }

    /// Publisher of active home preferences changes. Each emitted value has credentials injected from Keychain.
    var currentHomePreferencesPublisher: AnyPublisher<HomePreferences, Never> {
        $_currentHomePreferences
            .map { prefs in
                var p1 = prefs
                if let creds = CredentialsStore.retrieve(homeId: p1.id, type: .local) {
                    p1.localConnectionConfig.username = creds.username
                    p1.localConnectionConfig.password = creds.password
                }
                if let creds = CredentialsStore.retrieve(homeId: p1.id, type: .remote) {
                    p1.remoteConnectionConfig.username = creds.username
                    p1.remoteConnectionConfig.password = creds.password
                }
                return p1
            }
            .eraseToAnyPublisher()
    }

    /// AsyncStream that emits current home preferences (with credentials) immediately then on every change.
    /// Use in SwiftUI `.task {}` to keep a `@State` property in sync without manual cancellation.
    var currentHomePreferencesStream: AsyncStream<HomePreferences> {
        ensureMigrated()
        let publisher = currentHomePreferencesPublisher
        return AsyncStream { continuation in
            let box = CancellableBox()
            box.cancellable = publisher.sink { value in
                continuation.yield(value)
            }
            continuation.onTermination = { _ in
                box.cancellable?.cancel()
            }
        }
    }

    /// AsyncStream that emits `sendCrashReports` immediately then on every change.
    var sendCrashReportsStream: AsyncStream<Bool> {
        ensureMigrated()
        let publisher = $sendCrashReports
        return AsyncStream { continuation in
            let box = CancellableBox()
            box.cancellable = publisher.sink { value in
                continuation.yield(value)
            }
            continuation.onTermination = { _ in
                box.cancellable?.cancel()
            }
        }
    }
}

// MARK: Multiple homes

public extension Preferences {
    func listStoredHomes() -> [UUID] {
        ensureMigrated()
        let existing = Set(storedHomes.keys)
        // Return homes in persisted order, filtered to homes that still exist.
        let ordered = homeOrder.filter { existing.contains($0) }
        // Append any homes not yet in homeOrder (migration / new installs).
        let known = Set(ordered)
        let unordered = storedHomes.keys
            .filter { !known.contains($0) }
            .sorted { storedHomes[$0]?.homeName ?? "" <= storedHomes[$1]?.homeName ?? "" }
        return ordered + unordered
    }

    /// Persists a new home display order. Only UUIDs that exist in `storedHomes` are kept.
    func updateHomeOrder(_ order: [UUID]) {
        homeOrder = order.filter { storedHomes[$0] != nil }
    }

    func createAndLoadNewStoredSettings(homeName: String) {
        activeHomeId = UUID()
        var newHome = HomePreferences(id: activeHomeId)
        newHome.homeName = homeName
        homeOrder = homeOrder + [activeHomeId]
        loadHomePreferences(newHome)
    }

    func renameHome(_ homeId: UUID, newHomeName: String) {
        if homeId == activeHomeId {
            modifyActiveHome {
                $0.homeName = newHomeName
            }
        } else {
            var stored = storedHomes
            stored[homeId]?.homeName = newHomeName
            storedHomes = stored
        }
    }

    /// helper function for when we update the remote connection cloudUserId for notifications
    func setCloudUserId(_ cloudUserId: String?, for homeId: UUID) {
        if homeId == activeHomeId {
            modifyActiveHome { homePreferences in
                homePreferences.remoteConnectionConfig.cloudUserId = cloudUserId
            }
        } else {
            var stored = storedHomes
            var home = stored[homeId]
            home?.remoteConnectionConfig.cloudUserId = cloudUserId
            stored[homeId] = home
            storedHomes = stored
        }
    }

    func deleteStoredHome(_ homeId: UUID) {
        guard homeId != activeHomeId else {
            // cannot remove current home
            return
        }
        var stored = storedHomes
        stored.removeValue(forKey: homeId)
        storedHomes = stored
        homeOrder = homeOrder.filter { $0 != homeId }
        CredentialsStore.delete(homeId: homeId, type: .local)
        CredentialsStore.delete(homeId: homeId, type: .remote)
    }

    func switchActiveHome(to homeId: UUID) {
        guard let storedHome = storedHomes[homeId] else {
            // we have not stored our settings in that list yet
            return
        }

        activeHomeId = homeId

        loadHomePreferences(storedHome)
    }

    private func initializeStoredHomes() {
        if storedHomes.isEmpty {
            // first there might be no stored preferences, if no preference was changed since the update
            storeActiveHome()
        }
        // Migrate existing homes into homeOrder if it hasn't been populated yet
        // (first launch after this feature, or fresh install). Alphabetical sort
        // matches the previous listStoredHomes() behaviour so existing users see
        // no change until they reorder manually.
        if homeOrder.isEmpty, !storedHomes.isEmpty {
            homeOrder = storedHomes
                .sorted { $0.value.homeName <= $1.value.homeName }
                .map(\.key)
        }
    }

    private func loadHomePreferences(_ preferences: HomePreferences) {
        internalPreferenceChange {
            _currentHomePreferences = preferences
        }
        storeActiveHome() // store home settings in case they were not yet there
    }

    private func storeActiveHome() {
        var all = storedHomes
        let homeId = activeHomeId
        all[homeId] = currentHomePreferences
        storedHomes = all
        Logger.preferences.debug("Stored preferences for current home \(homeId.uuidString)")
    }

    func modifyActiveHome(modificationFunction: (inout HomePreferences) -> Void) {
        var homePreferences = currentHomePreferences // credentials injected from Keychain
        modificationFunction(&homePreferences)
        // Persist credentials to Keychain before storing the rest to UserDefaults
        CredentialsStore.store(
            username: homePreferences.localConnectionConfig.username,
            password: homePreferences.localConnectionConfig.password,
            homeId: homePreferences.id,
            type: .local
        )
        CredentialsStore.store(
            username: homePreferences.remoteConnectionConfig.username,
            password: homePreferences.remoteConnectionConfig.password,
            homeId: homePreferences.id,
            type: .remote
        )
        _currentHomePreferences = homePreferences // encodes without credentials
        storeActiveHome()
    }

    func modifyApplicationPreferences(modificationFunction: @Sendable (inout ApplicationPreferences) -> Void) {
        var applicationPreferences = applicationPreferences
        modificationFunction(&applicationPreferences)
        self.applicationPreferences = applicationPreferences
    }

    func setIdleOff(_ value: Bool) { idleOff = value }
    func setSendCrashReports(_ value: Bool) { sendCrashReports = value }
    func setHideStatusBar(_ value: Bool) { hideStatusBar = value }
    func setCurrentWebViewPath(_ value: String) { currentWebViewPath = value }

    /// Returns a snapshot of all screensaver settings in one actor call.
    func screensaverPreferences() -> ScreenSaverPreferences {
        ScreenSaverPreferences(
            isEnabled: screensaverEnabled,
            showsTime: screensaverShowsTime,
            showsDate: screensaverShowsDate,
            idleInterval: screensaverIdleInterval,
            movementInterval: screensaverMovementInterval,
            fontName: screensaverFontName,
            timeFontSizeRatio: screensaverTimeFontRatio,
            dateFontRelativeSize: screensaverDateFontRatio,
            enablesAutoDimming: screensaverEnableDimming,
            dimLevel: screensaverDimLevel,
            wakeBrightnessLevel: screensaverWakeBrightness,
            showsSeconds: screensaverShowsSeconds,
            uses24HourTime: screensaverUse24Hour,
            fadeDuration: screensaverFadeDuration,
            restoresBrightness: screensaverRestoreBrightness
        )
    }

    /// Writes all screensaver settings from a snapshot in one actor call.
    func saveScreenSaverSettings(_ prefs: ScreenSaverPreferences) {
        screensaverEnabled = prefs.isEnabled
        screensaverShowsTime = prefs.showsTime
        screensaverShowsDate = prefs.showsDate
        screensaverIdleInterval = prefs.idleInterval
        screensaverMovementInterval = prefs.movementInterval
        screensaverFontName = prefs.fontName
        screensaverTimeFontRatio = prefs.timeFontSizeRatio
        screensaverDateFontRatio = prefs.dateFontRelativeSize
        screensaverEnableDimming = prefs.enablesAutoDimming
        screensaverDimLevel = prefs.dimLevel
        screensaverWakeBrightness = prefs.wakeBrightnessLevel
        screensaverShowsSeconds = prefs.showsSeconds
        screensaverUse24Hour = prefs.uses24HourTime
        screensaverFadeDuration = prefs.fadeDuration
        screensaverRestoreBrightness = prefs.restoresBrightness
    }

    /// Modify an arbitrary stored home by UUID.  If `homeId` matches the active home,
    /// delegates to `modifyActiveHome` so that `currentHomePreferences` stays in sync.
    func modifyStoredHome(_ homeId: UUID, modificationFunction: @Sendable (inout HomePreferences) -> Void) {
        if homeId == activeHomeId {
            modifyActiveHome(modificationFunction: modificationFunction)
        } else {
            var stored = storedHomes
            guard stored[homeId] != nil else { return }
            modificationFunction(&stored[homeId]!)
            let home = stored[homeId]!
            CredentialsStore.store(
                username: home.localConnectionConfig.username,
                password: home.localConnectionConfig.password,
                homeId: homeId,
                type: .local
            )
            CredentialsStore.store(
                username: home.remoteConnectionConfig.username,
                password: home.remoteConnectionConfig.password,
                homeId: homeId,
                type: .remote
            )
            storedHomes = stored
        }
    }
}

public extension Preferences {
    func firstStoredHome(where predicate: (HomePreferences) -> Bool) -> (id: UUID, record: HomePreferences)? {
        ensureMigrated()
        for (uuid, record) in storedHomes {
            guard predicate(record) else { continue }
            return (uuid, record)
        }
        return nil
    }

    func storedHome(forCloudUserId id: String) -> HomePreferences? {
        guard var home = firstStoredHome(where: { $0.remoteConnectionConfig.cloudUserId == id })?.record else {
            return nil
        }
        if let creds = CredentialsStore.retrieve(homeId: home.id, type: .local) {
            home.localConnectionConfig.username = creds.username
            home.localConnectionConfig.password = creds.password
        }
        if let creds = CredentialsStore.retrieve(homeId: home.id, type: .remote) {
            home.remoteConnectionConfig.username = creds.username
            home.remoteConnectionConfig.password = creds.password
        }
        return home
    }
}

// MARK: Migration

extension Preferences {
    private func migrateToSharedDefaultsIfRequired() {
        guard !didMigrateToSharedDefaults else { return }

        modifyActiveHome { currentHomePreferences in
            currentHomePreferences.localConnectionConfig.url = UserDefaults.standard.string(forKey: "localUrl") ?? currentHomePreferences.localConnectionConfig.url
            currentHomePreferences.localConnectionConfig.alwaysSendBasicAuth = UserDefaults.standard.object(forKey: "alwaysSendCreds") as? Bool ?? currentHomePreferences.localConnectionConfig.alwaysSendBasicAuth
            currentHomePreferences.localConnectionConfig.ignoreSSL = UserDefaults.standard.object(forKey: "ignoreSSL") as? Bool ?? currentHomePreferences.localConnectionConfig.ignoreSSL
            currentHomePreferences.remoteConnectionConfig.url = UserDefaults.standard.string(forKey: "remoteUrl") ?? currentHomePreferences.remoteConnectionConfig.url
            currentHomePreferences.remoteConnectionConfig.username = UserDefaults.standard.string(forKey: "username") ?? currentHomePreferences.remoteConnectionConfig.username
            currentHomePreferences.remoteConnectionConfig.password = UserDefaults.standard.string(forKey: "password") ?? currentHomePreferences.remoteConnectionConfig.password
            currentHomePreferences.remoteConnectionConfig.alwaysSendBasicAuth = UserDefaults.standard.object(forKey: "alwaysSendCreds") as? Bool ?? currentHomePreferences.remoteConnectionConfig.alwaysSendBasicAuth
            currentHomePreferences.remoteConnectionConfig.ignoreSSL = UserDefaults.standard.object(forKey: "ignoreSSL") as? Bool ?? currentHomePreferences.remoteConnectionConfig.ignoreSSL
            currentHomePreferences.demomode = UserDefaults.standard.object(forKey: "demomode") as? Bool ?? currentHomePreferences.demomode
            currentHomePreferences.realTimeSliders = UserDefaults.standard.object(forKey: "realTimeSliders") as? Bool ?? currentHomePreferences.realTimeSliders
            currentHomePreferences.iconType = UserDefaults.standard.object(forKey: "iconType") as? Int ?? currentHomePreferences.iconType
            currentHomePreferences.defaultSitemap = UserDefaults.standard.string(forKey: "defaultSitemap") ?? currentHomePreferences.defaultSitemap
        }

        idleOff = UserDefaults.standard.object(forKey: "idleOff") as? Bool ?? idleOff
        sendCrashReports = UserDefaults.standard.object(forKey: "sendCrashReports") as? Bool ?? sendCrashReports

        didMigrateToSharedDefaults = true
        // this was done implicitly
        didMigrateToMultipleHomes = true
    }

    private func migrateToMultipleHomesIfRequired() {
        guard !didMigrateToMultipleHomes else { return }

        migrateToSharedDefaultsIfRequired()

        let oldLocalUrl = sharedDefaults.string(forKey: "localUrl")
        let oldRemoteUrl = sharedDefaults.string(forKey: "remoteUrl")
        let oldUsername = sharedDefaults.string(forKey: "username")
        let oldPassword = sharedDefaults.string(forKey: "password")
        let oldAlwaysSendCreds = sharedDefaults.object(forKey: "alwaysSendCreds") as? Bool
        let oldIgnoreSSL = sharedDefaults.object(forKey: "ignoreSSL") as? Bool

        // Create new configuration
        var newLocalConfiguration = currentHomePreferences.localConnectionConfig
        newLocalConfiguration.url = oldLocalUrl ?? newLocalConfiguration.url
        newLocalConfiguration.alwaysSendBasicAuth = oldAlwaysSendCreds ?? newLocalConfiguration.alwaysSendBasicAuth
        newLocalConfiguration.ignoreSSL = oldIgnoreSSL ?? newLocalConfiguration.ignoreSSL

        var newRemoteConfiguration = currentHomePreferences.remoteConnectionConfig
        newRemoteConfiguration.url = oldRemoteUrl ?? newRemoteConfiguration.url
        newRemoteConfiguration.username = oldUsername ?? newRemoteConfiguration.username
        newRemoteConfiguration.password = oldPassword ?? newRemoteConfiguration.password
        newRemoteConfiguration.alwaysSendBasicAuth = oldAlwaysSendCreds ?? newRemoteConfiguration.alwaysSendBasicAuth
        newRemoteConfiguration.ignoreSSL = oldIgnoreSSL ?? newRemoteConfiguration.ignoreSSL

        // Save to Preferences
        modifyActiveHome { [sharedDefaults] currentHomePreferences in
            currentHomePreferences.defaultView = sharedDefaults.string(forKey: "defaultView") ?? currentHomePreferences.defaultView
            currentHomePreferences.demomode = sharedDefaults.object(forKey: "demomode") as? Bool ?? currentHomePreferences.demomode
            currentHomePreferences.realTimeSliders = sharedDefaults.object(forKey: "realTimeSliders") as? Bool ?? currentHomePreferences.realTimeSliders
            currentHomePreferences.iconType = sharedDefaults.object(forKey: "iconType") as? Int ?? currentHomePreferences.iconType
            currentHomePreferences.defaultSitemap = sharedDefaults.string(forKey: "defaultSitemap") ?? currentHomePreferences.defaultSitemap
            currentHomePreferences.sortSitemapsBy = sharedDefaults.object(forKey: "sortSitemapsBy") as? Int ?? currentHomePreferences.sortSitemapsBy
            currentHomePreferences.defaultMainUIPath = sharedDefaults.string(forKey: "defaultMainUIPath") ?? currentHomePreferences.defaultMainUIPath
            currentHomePreferences.alwaysAllowWebRTC = sharedDefaults.object(forKey: "alwaysAllowWebRTC") as? Bool ?? currentHomePreferences.alwaysAllowWebRTC
            currentHomePreferences.sitemapForWatch = sharedDefaults.string(forKey: "sitemapForWatch") ?? currentHomePreferences.sitemapForWatch
            currentHomePreferences.localConnectionConfig = newLocalConfiguration
            currentHomePreferences.remoteConnectionConfig = newRemoteConfiguration
            currentHomePreferences.sitemapForWatchLabel = sharedDefaults.string(forKey: "sitemapForWatchLabel") ?? currentHomePreferences.sitemapForWatchLabel
        }

        didMigrateToMultipleHomes = true
    }

    private func migrateCredentialsToKeychainIfRequired() {
        guard !didMigrateCredentialsToKeychain else { return }

        // storedHomes decodes from JSON; init(from:) uses decodeIfPresent so old credentials are still read
        for (homeId, home) in storedHomes {
            CredentialsStore.store(
                username: home.localConnectionConfig.username,
                password: home.localConnectionConfig.password,
                homeId: homeId,
                type: .local
            )
            CredentialsStore.store(
                username: home.remoteConnectionConfig.username,
                password: home.remoteConnectionConfig.password,
                homeId: homeId,
                type: .remote
            )
        }

        didMigrateCredentialsToKeychain = true
    }
}

// MARK: All connections

public extension Preferences {
    func getNotificationConnection() -> ConnectionConfiguration? {
        ensureMigrated()
        return Preferences.getNotificationConnection(of: [currentHomePreferences.remoteConnectionConfig])
    }

    static func getNotificationConnection(of homeConfig: HomePreferences) -> ConnectionConfiguration? {
        getNotificationConnection(of: [homeConfig.remoteConnectionConfig])
    }

    /// this will support mutliple connection configs, right now we just pass in the remote config
    static func getNotificationConnection(of connections: [ConnectionConfiguration?]) -> ConnectionConfiguration? {
        connections
            .compactMap(\.self)
            .filter { $0.supportsNotifications == true }
            .sorted { $0.priority > $1.priority }
            .first
    }

    var storedHomesStream: AsyncStream<[UUID: HomePreferences]> {
        let publisher = $storedHomes
        return AsyncStream { continuation in
            let box = CancellableBox()
            box.cancellable = publisher.sink { value in continuation.yield(value) }
            continuation.onTermination = { _ in box.cancellable?.cancel() }
        }
    }
}

// MARK: - Sample Codable Model

public extension ConnectionConfiguration {
    static let localDefault = ConnectionConfiguration(
        url: "https://openhab.local:8443",
        username: "",
        password: "",
        alwaysSendBasicAuth: false,
        ignoreSSL: false,
        supportsNotifications: false,
        priority: 0
    )

    static let remoteDefault = ConnectionConfiguration(
        url: "https://myopenhab.org",
        username: "",
        password: "",
        alwaysSendBasicAuth: false,
        ignoreSSL: false,
        supportsNotifications: true,
        priority: 1
    )

    /// The single connection every demo home is tracked against, regardless of its
    /// stored local/remote configuration.
    static let demo = ConnectionConfiguration(
        url: "https://demo.openhab.org",
        username: "",
        password: "",
        priority: 0
    )
}
