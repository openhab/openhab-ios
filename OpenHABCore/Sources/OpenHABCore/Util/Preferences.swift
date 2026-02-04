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
import UIKit

private let sharedDefaults = UserDefaults(suiteName: "group.org.openhab.app")!

@propertyWrapper
private struct Preference<T: Sendable> {
    private let keyPath: WritableKeyPath<PreferencesStore, T>
    private let subject: CurrentValueSubject<T, Never>

    var wrappedValue: T {
        get {
            PreferencesStoreAccess.shared.value(for: keyPath)
        }
        set {
            PreferencesStoreAccess.shared.setValue(newValue, for: keyPath)
            subject.send(newValue)
        }
    }

    var projectedValue: AnyPublisher<T, Never> {
        subject.eraseToAnyPublisher()
    }

    init(_ keyPath: WritableKeyPath<PreferencesStore, T>) {
        self.keyPath = keyPath
        let currentValue = PreferencesStoreAccess.shared.value(for: keyPath)
        subject = CurrentValueSubject<T, Never>(currentValue)
    }
}

private struct PreferencesStore: Codable, Sendable, Equatable {
    static let currentVersion = 1

    var version: Int
    var currentHomePreferences: HomePreferences
    var storedHomes: [UUID: HomePreferences]
    var activeHomeId: UUID
    var applicationPreferences: ApplicationPreferences
    var sendCrashReports: Bool
    var idleOff: Bool
    var screensaverEnabled: Bool
    var screensaverShowsTime: Bool
    var screensaverShowsDate: Bool
    var screensaverIdleInterval: Double
    var screensaverMovementInterval: Double
    var screensaverFontName: String
    var screensaverTimeFontRatio: Double
    var screensaverDateFontRatio: Double
    var screensaverEnableDimming: Bool
    var screensaverDimLevel: Double
    var screensaverShowsSeconds: Bool
    var screensaverUse24Hour: Bool
    var screensaverFadeDuration: Double
    var screensaverRestoreBrightness: Bool
    var screensaverWakeBrightness: Double
    var hideStatusBar: Bool
    var currentWebViewPath: String

    private enum CodingKeys: String, CodingKey {
        case version
        case currentHomePreferences
        case storedHomes
        case activeHomeId
        case applicationPreferences
        case sendCrashReports
        case idleOff
        case screensaverEnabled
        case screensaverShowsTime
        case screensaverShowsDate
        case screensaverIdleInterval
        case screensaverMovementInterval
        case screensaverFontName
        case screensaverTimeFontRatio
        case screensaverDateFontRatio
        case screensaverEnableDimming
        case screensaverDimLevel
        case screensaverShowsSeconds
        case screensaverUse24Hour
        case screensaverFadeDuration
        case screensaverRestoreBrightness
        case screensaverWakeBrightness
        case hideStatusBar
        case currentWebViewPath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = PreferencesStore.defaultStore()
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? defaults.version
        currentHomePreferences = try container.decodeIfPresent(HomePreferences.self, forKey: .currentHomePreferences) ?? defaults.currentHomePreferences
        storedHomes = try container.decodeIfPresent([UUID: HomePreferences].self, forKey: .storedHomes) ?? defaults.storedHomes
        activeHomeId = try container.decodeIfPresent(UUID.self, forKey: .activeHomeId) ?? defaults.activeHomeId
        applicationPreferences = try container.decodeIfPresent(ApplicationPreferences.self, forKey: .applicationPreferences) ?? defaults.applicationPreferences
        sendCrashReports = try container.decodeIfPresent(Bool.self, forKey: .sendCrashReports) ?? defaults.sendCrashReports
        idleOff = try container.decodeIfPresent(Bool.self, forKey: .idleOff) ?? defaults.idleOff
        screensaverEnabled = try container.decodeIfPresent(Bool.self, forKey: .screensaverEnabled) ?? defaults.screensaverEnabled
        screensaverShowsTime = try container.decodeIfPresent(Bool.self, forKey: .screensaverShowsTime) ?? defaults.screensaverShowsTime
        screensaverShowsDate = try container.decodeIfPresent(Bool.self, forKey: .screensaverShowsDate) ?? defaults.screensaverShowsDate
        screensaverIdleInterval = try container.decodeIfPresent(Double.self, forKey: .screensaverIdleInterval) ?? defaults.screensaverIdleInterval
        screensaverMovementInterval = try container.decodeIfPresent(Double.self, forKey: .screensaverMovementInterval) ?? defaults.screensaverMovementInterval
        screensaverFontName = try container.decodeIfPresent(String.self, forKey: .screensaverFontName) ?? defaults.screensaverFontName
        screensaverTimeFontRatio = try container.decodeIfPresent(Double.self, forKey: .screensaverTimeFontRatio) ?? defaults.screensaverTimeFontRatio
        screensaverDateFontRatio = try container.decodeIfPresent(Double.self, forKey: .screensaverDateFontRatio) ?? defaults.screensaverDateFontRatio
        screensaverEnableDimming = try container.decodeIfPresent(Bool.self, forKey: .screensaverEnableDimming) ?? defaults.screensaverEnableDimming
        screensaverDimLevel = try container.decodeIfPresent(Double.self, forKey: .screensaverDimLevel) ?? defaults.screensaverDimLevel
        screensaverShowsSeconds = try container.decodeIfPresent(Bool.self, forKey: .screensaverShowsSeconds) ?? defaults.screensaverShowsSeconds
        screensaverUse24Hour = try container.decodeIfPresent(Bool.self, forKey: .screensaverUse24Hour) ?? defaults.screensaverUse24Hour
        screensaverFadeDuration = try container.decodeIfPresent(Double.self, forKey: .screensaverFadeDuration) ?? defaults.screensaverFadeDuration
        screensaverRestoreBrightness = try container.decodeIfPresent(Bool.self, forKey: .screensaverRestoreBrightness) ?? defaults.screensaverRestoreBrightness
        screensaverWakeBrightness = try container.decodeIfPresent(Double.self, forKey: .screensaverWakeBrightness) ?? defaults.screensaverWakeBrightness
        hideStatusBar = try container.decodeIfPresent(Bool.self, forKey: .hideStatusBar) ?? defaults.hideStatusBar
        currentWebViewPath = try container.decodeIfPresent(String.self, forKey: .currentWebViewPath) ?? defaults.currentWebViewPath
    }

    static func defaultStore() -> PreferencesStore {
        let homeId = UUID()
        let home = HomePreferences(id: homeId)
        return PreferencesStore(
            version: currentVersion,
            currentHomePreferences: home,
            storedHomes: [homeId: home],
            activeHomeId: homeId,
            applicationPreferences: ApplicationPreferences(),
            sendCrashReports: false,
            idleOff: false,
            screensaverEnabled: false,
            screensaverShowsTime: true,
            screensaverShowsDate: true,
            screensaverIdleInterval: 120.0,
            screensaverMovementInterval: 8.0,
            screensaverFontName: "",
            screensaverTimeFontRatio: 0.2,
            screensaverDateFontRatio: 0.4,
            screensaverEnableDimming: true,
            screensaverDimLevel: 0.3,
            screensaverShowsSeconds: false,
            screensaverUse24Hour: false,
            screensaverFadeDuration: 2.0,
            screensaverRestoreBrightness: true,
            screensaverWakeBrightness: 1.0,
            hideStatusBar: false,
            currentWebViewPath: ""
        )
    }
}

private final class PreferencesStoreAccess {
    static let shared = PreferencesStoreAccess()
    private static let storeKey = "preferencesStore"
    private var store: PreferencesStore

    private init() {
        store = Self.loadStore()
    }

    func value<T>(for keyPath: KeyPath<PreferencesStore, T>) -> T {
        store[keyPath: keyPath]
    }

    func setValue<T>(_ value: T, for keyPath: WritableKeyPath<PreferencesStore, T>) {
        store[keyPath: keyPath] = value
        persistStore()
    }

    static func migrateIfNeeded() {
        _ = PreferencesStoreAccess.shared
    }

    private static func loadStore() -> PreferencesStore {
        if let data = sharedDefaults.data(forKey: storeKey) {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode(PreferencesStore.self, from: data) {
                if decoded.version == PreferencesStore.currentVersion {
                    return decoded
                }
                return migrateStore(decoded)
            } else {
                Logger.preferences.error("Preferences JSON failed to decode, falling back to legacy preferences.")
            }
        }

        let legacyStore = LegacyPreferencesMapper.loadStore()
        persistStore(legacyStore)
        return legacyStore
    }

    private static func migrateStore(_ store: PreferencesStore) -> PreferencesStore {
        var migrated = store
        migrated.version = PreferencesStore.currentVersion
        persistStore(migrated)
        return migrated
    }

    private func persistStore() {
        Self.persistStore(store)
    }

    private static func persistStore(_ store: PreferencesStore) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(store) else {
            Logger.preferences.error("Failed to encode preferences JSON.")
            return
        }
        sharedDefaults.set(data, forKey: storeKey)
    }

    #if DEBUG
    func reloadFromDefaultsForTesting() {
        store = Self.loadStore()
    }
    #endif
}

private enum LegacyPreferencesMapper {
    static func loadStore() -> PreferencesStore {
        let decoder = JSONDecoder()
        var store = PreferencesStore.defaultStore()

        if let data = sharedDefaults.data(forKey: "currentHomePreferences"),
           let decoded = try? decoder.decode(HomePreferences.self, from: data) {
            store.currentHomePreferences = decoded
        }

        if let data = sharedDefaults.data(forKey: "storedHomes"),
           let decoded = try? decoder.decode([UUID: HomePreferences].self, from: data) {
            store.storedHomes = decoded
        }

        if let data = sharedDefaults.data(forKey: "activeHomeId"),
           let decoded = try? decoder.decode(UUID.self, from: data) {
            store.activeHomeId = decoded
        }

        if let data = sharedDefaults.data(forKey: "applicationPreferences"),
           let decoded = try? decoder.decode(ApplicationPreferences.self, from: data) {
            store.applicationPreferences = decoded
        }

        store.sendCrashReports = sharedDefaults.object(forKey: "sendCrashReports") as? Bool ?? store.sendCrashReports
        store.idleOff = sharedDefaults.object(forKey: "idleOff") as? Bool ?? store.idleOff
        store.screensaverEnabled = sharedDefaults.object(forKey: "screensaverEnabled") as? Bool ?? store.screensaverEnabled
        store.screensaverShowsTime = sharedDefaults.object(forKey: "screensaverShowsTime") as? Bool ?? store.screensaverShowsTime
        store.screensaverShowsDate = sharedDefaults.object(forKey: "screensaverShowsDate") as? Bool ?? store.screensaverShowsDate
        store.screensaverIdleInterval = sharedDefaults.object(forKey: "screensaverIdleInterval") as? Double ?? store.screensaverIdleInterval
        store.screensaverMovementInterval = sharedDefaults.object(forKey: "screensaverMovementInterval") as? Double ?? store.screensaverMovementInterval
        store.screensaverFontName = sharedDefaults.string(forKey: "screensaverFontName") ?? store.screensaverFontName
        store.screensaverTimeFontRatio = sharedDefaults.object(forKey: "screensaverTimeFontRatio") as? Double ?? store.screensaverTimeFontRatio
        store.screensaverDateFontRatio = sharedDefaults.object(forKey: "screensaverDateFontRatio") as? Double ?? store.screensaverDateFontRatio
        store.screensaverEnableDimming = sharedDefaults.object(forKey: "screensaverEnableDimming") as? Bool ?? store.screensaverEnableDimming
        store.screensaverDimLevel = sharedDefaults.object(forKey: "screensaverDimLevel") as? Double ?? store.screensaverDimLevel
        store.screensaverShowsSeconds = sharedDefaults.object(forKey: "screensaverShowsSeconds") as? Bool ?? store.screensaverShowsSeconds
        store.screensaverUse24Hour = sharedDefaults.object(forKey: "screensaverUse24Hour") as? Bool ?? store.screensaverUse24Hour
        store.screensaverFadeDuration = sharedDefaults.object(forKey: "screensaverFadeDuration") as? Double ?? store.screensaverFadeDuration
        store.screensaverRestoreBrightness = sharedDefaults.object(forKey: "screensaverRestoreBrightness") as? Bool ?? store.screensaverRestoreBrightness
        store.screensaverWakeBrightness = sharedDefaults.object(forKey: "screensaverWakeBrightness") as? Double ?? store.screensaverWakeBrightness
        store.hideStatusBar = sharedDefaults.object(forKey: "hideStatusBar") as? Bool ?? store.hideStatusBar
        store.currentWebViewPath = sharedDefaults.string(forKey: "currentWebViewPath") ?? store.currentWebViewPath

        let didMigrateToSharedDefaults = sharedDefaults.bool(forKey: "didMigrateToSharedDefaults")
        let didMigrateToMultipleHomes = sharedDefaults.bool(forKey: "didMigrateToMultipleHomes")

        if !didMigrateToSharedDefaults {
            applyStandardDefaultsMigration(to: &store)
            sharedDefaults.set(true, forKey: "didMigrateToSharedDefaults")
            sharedDefaults.set(true, forKey: "didMigrateToMultipleHomes")
        }

        if !didMigrateToMultipleHomes {
            applyMultipleHomesMigration(to: &store)
            sharedDefaults.set(true, forKey: "didMigrateToMultipleHomes")
        }

        if store.storedHomes.isEmpty {
            store.storedHomes[store.currentHomePreferences.id] = store.currentHomePreferences
        }

        if store.storedHomes[store.activeHomeId] == nil {
            store.storedHomes[store.activeHomeId] = store.currentHomePreferences
        }

        if let storedHome = store.storedHomes[store.activeHomeId] {
            store.currentHomePreferences = storedHome
        }

        return store
    }

    private static func applyStandardDefaultsMigration(to store: inout PreferencesStore) {
        let standardDefaults = UserDefaults.standard
        store.currentHomePreferences.localConnectionConfig.url = standardDefaults.string(forKey: "localUrl") ?? store.currentHomePreferences.localConnectionConfig.url
        store.currentHomePreferences.localConnectionConfig.alwaysSendBasicAuth = standardDefaults.object(forKey: "alwaysSendCreds") as? Bool ?? store.currentHomePreferences.localConnectionConfig.alwaysSendBasicAuth
        store.currentHomePreferences.localConnectionConfig.ignoreSSL = standardDefaults.object(forKey: "ignoreSSL") as? Bool ?? store.currentHomePreferences.localConnectionConfig.ignoreSSL
        store.currentHomePreferences.remoteConnectionConfig.url = standardDefaults.string(forKey: "remoteUrl") ?? store.currentHomePreferences.remoteConnectionConfig.url
        store.currentHomePreferences.remoteConnectionConfig.username = standardDefaults.string(forKey: "username") ?? store.currentHomePreferences.remoteConnectionConfig.username
        store.currentHomePreferences.remoteConnectionConfig.password = standardDefaults.string(forKey: "password") ?? store.currentHomePreferences.remoteConnectionConfig.password
        store.currentHomePreferences.remoteConnectionConfig.alwaysSendBasicAuth = standardDefaults.object(forKey: "alwaysSendCreds") as? Bool ?? store.currentHomePreferences.remoteConnectionConfig.alwaysSendBasicAuth
        store.currentHomePreferences.remoteConnectionConfig.ignoreSSL = standardDefaults.object(forKey: "ignoreSSL") as? Bool ?? store.currentHomePreferences.remoteConnectionConfig.ignoreSSL
        store.currentHomePreferences.demomode = standardDefaults.object(forKey: "demomode") as? Bool ?? store.currentHomePreferences.demomode
        store.currentHomePreferences.realTimeSliders = standardDefaults.object(forKey: "realTimeSliders") as? Bool ?? store.currentHomePreferences.realTimeSliders
        store.currentHomePreferences.iconType = standardDefaults.object(forKey: "iconType") as? Int ?? store.currentHomePreferences.iconType
        store.currentHomePreferences.defaultSitemap = standardDefaults.string(forKey: "defaultSitemap") ?? store.currentHomePreferences.defaultSitemap

        store.idleOff = standardDefaults.object(forKey: "idleOff") as? Bool ?? store.idleOff
        store.sendCrashReports = standardDefaults.object(forKey: "sendCrashReports") as? Bool ?? store.sendCrashReports
    }

    private static func applyMultipleHomesMigration(to store: inout PreferencesStore) {
        let oldLocalUrl = sharedDefaults.string(forKey: "localUrl")
        let oldRemoteUrl = sharedDefaults.string(forKey: "remoteUrl")
        let oldUsername = sharedDefaults.string(forKey: "username")
        let oldPassword = sharedDefaults.string(forKey: "password")
        let oldAlwaysSendCreds = sharedDefaults.object(forKey: "alwaysSendCreds") as? Bool
        let oldIgnoreSSL = sharedDefaults.object(forKey: "ignoreSSL") as? Bool

        var newLocalConfiguration = store.currentHomePreferences.localConnectionConfig
        newLocalConfiguration.url = oldLocalUrl ?? newLocalConfiguration.url
        newLocalConfiguration.alwaysSendBasicAuth = oldAlwaysSendCreds ?? newLocalConfiguration.alwaysSendBasicAuth
        newLocalConfiguration.ignoreSSL = oldIgnoreSSL ?? newLocalConfiguration.ignoreSSL

        var newRemoteConfiguration = store.currentHomePreferences.remoteConnectionConfig
        newRemoteConfiguration.url = oldRemoteUrl ?? newRemoteConfiguration.url
        newRemoteConfiguration.username = oldUsername ?? newRemoteConfiguration.username
        newRemoteConfiguration.password = oldPassword ?? newRemoteConfiguration.password
        newRemoteConfiguration.alwaysSendBasicAuth = oldAlwaysSendCreds ?? newRemoteConfiguration.alwaysSendBasicAuth
        newRemoteConfiguration.ignoreSSL = oldIgnoreSSL ?? newRemoteConfiguration.ignoreSSL

        store.currentHomePreferences.defaultView = sharedDefaults.string(forKey: "defaultView") ?? store.currentHomePreferences.defaultView
        store.currentHomePreferences.demomode = sharedDefaults.object(forKey: "demomode") as? Bool ?? store.currentHomePreferences.demomode
        store.currentHomePreferences.realTimeSliders = sharedDefaults.object(forKey: "realTimeSliders") as? Bool ?? store.currentHomePreferences.realTimeSliders
        store.currentHomePreferences.iconType = sharedDefaults.object(forKey: "iconType") as? Int ?? store.currentHomePreferences.iconType
        store.currentHomePreferences.defaultSitemap = sharedDefaults.string(forKey: "defaultSitemap") ?? store.currentHomePreferences.defaultSitemap
        store.currentHomePreferences.sortSitemapsBy = sharedDefaults.object(forKey: "sortSitemapsBy") as? Int ?? store.currentHomePreferences.sortSitemapsBy
        store.currentHomePreferences.defaultMainUIPath = sharedDefaults.string(forKey: "defaultMainUIPath") ?? store.currentHomePreferences.defaultMainUIPath
        store.currentHomePreferences.alwaysAllowWebRTC = sharedDefaults.object(forKey: "alwaysAllowWebRTC") as? Bool ?? store.currentHomePreferences.alwaysAllowWebRTC
        store.currentHomePreferences.sitemapForWatch = sharedDefaults.string(forKey: "sitemapForWatch") ?? store.currentHomePreferences.sitemapForWatch
        store.currentHomePreferences.localConnectionConfig = newLocalConfiguration
        store.currentHomePreferences.remoteConnectionConfig = newRemoteConfiguration
        store.currentHomePreferences.sitemapForWatchLabel = sharedDefaults.string(forKey: "sitemapForWatchLabel") ?? store.currentHomePreferences.sitemapForWatchLabel
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
    public var defaultMainUIPath = ""
    public var alwaysAllowWebRTC = false
    public var sitemapForWatch = "watch"
    public var localConnectionConfig: ConnectionConfiguration = .localDefault
    public var remoteConnectionConfig: ConnectionConfiguration = .remoteDefault
    public var sitemapForWatchLabel = "watch"
    public var homeName = "Home"
    public var sseCommandItem = ""

    fileprivate init(id: UUID) {
        self.id = id
    }
}

public struct ApplicationPreferences: Codable, Equatable, Sendable {
    public var showSearchField = true
}

// MARK: Preferences stored in JSON with versioning

@MainActor
public actor Preferences {
    public static let shared = Preferences()

    /// the currently applied settings set from storedHomes
    @Preference(\.currentHomePreferences)
    public private(set) var currentHomePreferences: HomePreferences

    @Preference(\.sendCrashReports)
    public var sendCrashReports: Bool

    @Preference(\.idleOff)
    public var idleOff: Bool

    @Preference(\.applicationPreferences)
    public private(set) var applicationPreferences: ApplicationPreferences

    @Preference(\.screensaverEnabled)
    public var screensaverEnabled: Bool

    @Preference(\.screensaverShowsTime)
    public var screensaverShowsTime: Bool

    @Preference(\.screensaverShowsDate)
    public var screensaverShowsDate: Bool

    @Preference(\.screensaverIdleInterval)
    public var screensaverIdleInterval: Double

    @Preference(\.screensaverMovementInterval)
    public var screensaverMovementInterval: Double

    @Preference(\.screensaverFontName)
    public var screensaverFontName: String

    @Preference(\.screensaverTimeFontRatio)
    public var screensaverTimeFontRatio: Double

    @Preference(\.screensaverDateFontRatio)
    public var screensaverDateFontRatio: Double

    @Preference(\.screensaverEnableDimming)
    public var screensaverEnableDimming: Bool

    @Preference(\.screensaverDimLevel)
    public var screensaverDimLevel: Double

    @Preference(\.screensaverShowsSeconds)
    public var screensaverShowsSeconds: Bool

    @Preference(\.screensaverUse24Hour)
    public var screensaverUse24Hour: Bool

    @Preference(\.screensaverFadeDuration)
    public var screensaverFadeDuration: Double

    @Preference(\.screensaverRestoreBrightness)
    public var screensaverRestoreBrightness: Bool

    @Preference(\.screensaverWakeBrightness)
    public var screensaverWakeBrightness: Double

    @Preference(\.hideStatusBar)
    public var hideStatusBar: Bool

    @Preference(\.currentWebViewPath)
    public var currentWebViewPath: String

    /// settings for different homes
    @Preference(\.storedHomes)
    public private(set) var storedHomes: [UUID: HomePreferences]

    /// the currently applied settings set from storedHomes
    @Preference(\.activeHomeId)
    private var activeHomeId: UUID

    private var internalPreferenceChangeOngoing = false

    private func internalPreferenceChange(_ change: () -> Void) {
        internalPreferenceChangeOngoing = true
        change()
        internalPreferenceChangeOngoing = false
    }
}

// MARK: Multiple homes

public extension Preferences {
    func listStoredHomes() -> [UUID] {
        let preferenceIds = storedHomes
            .sorted { e1, e2 in
                e1.value.homeName <= e2.value.homeName
            }
            .map(\.key)
        return preferenceIds
    }

    func createAndLoadNewStoredSettings(homeName: String) {
        activeHomeId = UUID()
        var newHome = HomePreferences(id: activeHomeId)
        newHome.homeName = homeName
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
    }

    private func loadHomePreferences(_ preferences: HomePreferences) {
        internalPreferenceChange {
            currentHomePreferences = preferences
        }
        storeActiveHome() // store home settings in case they were not yet there
    }

    private func storeActiveHome() {
        var all = storedHomes
        let homeId = Preferences.shared.activeHomeId
        all[homeId] = Preferences.shared.currentHomePreferences
        storedHomes = all
        Logger.preferences.debug("Stored preferences for current home \(homeId.uuidString)")
    }

    func modifyActiveHome(modificationFunction: (inout HomePreferences) -> Void) {
        var homePreferences = currentHomePreferences
        modificationFunction(&homePreferences)
        currentHomePreferences = homePreferences
        storeActiveHome()
    }

    func modifyApplicationPreferences(modificationFunction: (inout ApplicationPreferences) -> Void) {
        var applicationPreferences = applicationPreferences
        modificationFunction(&applicationPreferences)
        self.applicationPreferences = applicationPreferences
    }
}

public extension Preferences {
    func firstStoredHome(where predicate: (HomePreferences) -> Bool) -> (id: UUID, record: HomePreferences)? {
        for (uuid, record) in storedHomes {
            guard predicate(record) else { continue }
            return (uuid, record)
        }
        return nil
    }

    func storedHome(forCloudUserId id: String) -> HomePreferences? {
        firstStoredHome { homePreferences in
            homePreferences.remoteConnectionConfig.cloudUserId == id
        }?.record
    }
}

// MARK: Migration

public extension Preferences {
    static func migratePreferences() {
        PreferencesStoreAccess.migrateIfNeeded()
        Preferences.shared.initializeStoredHomes()
    }
}

#if DEBUG
public extension Preferences {
    static func reloadForTesting() {
        PreferencesStoreAccess.shared.reloadFromDefaultsForTesting()
        Preferences.shared.initializeStoredHomes()
    }
}
#endif

// MARK: All connections

public extension Preferences {
    func getNotificationConnection() -> ConnectionConfiguration? {
        getNotificationConnection(of: [Preferences.shared.currentHomePreferences.remoteConnectionConfig])
    }

    func getNotificationConnection(of homeConfig: HomePreferences) -> ConnectionConfiguration? {
        getNotificationConnection(of: [homeConfig.remoteConnectionConfig])
    }

    // this will support mutliple connection configs, right now we just pass in the remote config
    func getNotificationConnection(of connections: [ConnectionConfiguration?]) -> ConnectionConfiguration? {
        connections
            .compactMap(\.self)
            .filter { $0.supportsNotifications == true }
            .sorted { $0.priority > $1.priority }
            .first
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
}
