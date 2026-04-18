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

@MainActor
private let sharedDefaults = UserDefaults(suiteName: "group.org.openhab.app")!

@MainActor
@propertyWrapper
public struct UserDefault<T: Sendable> {
    private let key: String
    private let defaultValue: T
    private let isHomeProperty: Bool
    private let subject: CurrentValueSubject<T, Never>

    public var wrappedValue: T {
        get {
            PreferencesAccess.getPreference(key: key, defaultValue: defaultValue, encoder: { $0 }, decoder: { $0 as? T })
        }
        set {
            PreferencesAccess.preferenceChanged(newValue: newValue, key: key, isHomeProperty: isHomeProperty, subject: subject) { $0 }
        }
    }

    public var projectedValue: AnyPublisher<T, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(_ key: String, defaultValue: T, isHomeProperty: Bool = false) {
        self.key = key
        self.defaultValue = defaultValue
        self.isHomeProperty = isHomeProperty
        let currentValue = PreferencesAccess.getPreference(key: key, defaultValue: defaultValue, encoder: { $0 }, decoder: { $0 as? T })
        subject = CurrentValueSubject<T, Never>(currentValue)
    }
}

@MainActor
@propertyWrapper
public struct UserDefaultObject<T: Codable & Sendable> {
    private let key: String
    private let defaultValue: T
    private let isHomeProperty: Bool
    private let subject: CurrentValueSubject<T, Never>

    private let objectDecoder: (Any) -> (T?) = {
        guard let data = $0 as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private let objectEncoder: (T) -> (any Sendable)? = { try? JSONEncoder().encode($0) }

    public var wrappedValue: T {
        get {
            PreferencesAccess.getPreference(key: key, defaultValue: defaultValue, encoder: objectEncoder, decoder: objectDecoder)
        }
        set {
            PreferencesAccess.preferenceChanged(newValue: newValue, key: key, isHomeProperty: isHomeProperty, subject: subject, converter: objectEncoder)
        }
    }

    public var projectedValue: AnyPublisher<T, Never> {
        subject.eraseToAnyPublisher()
    }

    init(_ key: String, defaultValue: T, isHomeProperty: Bool = false) {
        self.key = key
        self.defaultValue = defaultValue
        self.isHomeProperty = isHomeProperty

        // Combine publication
        let currentValue = PreferencesAccess.getPreference(key: key, defaultValue: defaultValue, encoder: objectEncoder, decoder: objectDecoder)
        subject = CurrentValueSubject(currentValue)
    }
}

@MainActor
public struct HomePreferences: Codable, Equatable {
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

@MainActor
public struct ApplicationPreferences: Codable, Equatable {
    public var showSearchField = true
    public var sitemapDiagnosticsLogging = false

    public init(
        showSearchField: Bool = true,
        sitemapDiagnosticsLogging: Bool = false
    ) {
        self.showSearchField = showSearchField
        self.sitemapDiagnosticsLogging = sitemapDiagnosticsLogging
    }

    enum CodingKeys: String, CodingKey {
        case showSearchField
        case sitemapDiagnosticsLogging
    }

    nonisolated public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showSearchField = try container.decodeIfPresent(Bool.self, forKey: .showSearchField) ?? true
        sitemapDiagnosticsLogging = try container.decodeIfPresent(Bool.self, forKey: .sitemapDiagnosticsLogging) ?? false
    }
}

// MARK: Retrieving preference from user defaults, reacting to preference change

// MARK: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

// MARK: !!

// MARK: When making changes to Preferences, always consider a migration for existing users. Otherwise, they risk to loose their existing preferences.

// MARK: !!

// MARK: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

private enum PreferencesAccess {
    @MainActor fileprivate static func getPreference<T>(key: String, defaultValue: T, encoder: (T) -> (some Sendable)?, decoder: (Any?) -> T?) -> T {
        let preferenceValue = sharedDefaults.object(forKey: key)
        if let preferenceConverted = decoder(preferenceValue) {
            return preferenceConverted
        } else {
            if let preferenceValue {
                Logger.preferences.error("Preference value \(key) was \(String(describing: preferenceValue)) but did not conform to \(T.self). Replace with default value.")
            } else {
                Logger.preferences.info("Preference value \(key) was set for the first time. Using default value.")
            }
            let fallback = defaultValue
            sharedDefaults.set(encoder(fallback), forKey: key)
            return fallback
        }
    }

    @MainActor fileprivate static func preferenceChanged<T>(newValue: T, key: String, isHomeProperty: Bool, subject: CurrentValueSubject<T, Never>, sanitize: (T) -> (T?) = { $0 }, converter: (T) -> (some Sendable)?) {
        guard let sanitized = sanitize(newValue) else {
            Logger.preferences.debug("Preference \(key) new value \(String(describing: newValue), privacy: .private) could not be sanitized, will be ignored")
            return
        }
        let convertedValue = converter(sanitized)
        guard convertedValue != nil else {
            Logger.preferences.debug("Preference \(key) conversion of new value \(String(describing: sanitized), privacy: .private) failed, do not store.")
            return
        }
        Logger.preferences.debug("Preference \(key) will be changed to value \(String(describing: newValue), privacy: .private)")
        sharedDefaults.set(convertedValue, forKey: key)

        subject.send(sanitized)
    }
}

public actor Preferences {
    public static let shared = Preferences()

    private static let defaultHomeId = UUID()

    /// the currently applied settings set from storedHomes
    @UserDefaultObject("currentHomePreferences", defaultValue: HomePreferences(id: defaultHomeId))
    public private(set) var currentHomePreferences: HomePreferences

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
    @UserDefaultObject("storedHomes", defaultValue: [:])
    public private(set) var storedHomes: [UUID: HomePreferences]

    /// the currently applied settings set from storedHomes
    @UserDefaultObject("activeHomeId", defaultValue: defaultHomeId)
    private var activeHomeId: UUID

    @UserDefault("didMigrateToSharedDefaults", defaultValue: false)
    private var didMigrateToSharedDefaults: Bool

    @UserDefault("didMigrateToMultipleHomes", defaultValue: false)
    private var didMigrateToMultipleHomes: Bool

    @MainActor
    private var internalPreferenceChangeOngoing = false

    @MainActor
    private func internalPreferenceChange(_ change: () -> Void) {
        internalPreferenceChangeOngoing = true
        change()
        internalPreferenceChangeOngoing = false
    }
}

// MARK: Multiple homes

@MainActor
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

    func modifyActiveHome(modificationFunction: @MainActor (inout HomePreferences) -> Void) {
        var homePreferences = currentHomePreferences
        modificationFunction(&homePreferences)
        currentHomePreferences = homePreferences
        storeActiveHome()
    }

    func modifyApplicationPreferences(modificationFunction: @MainActor (inout ApplicationPreferences) -> Void) {
        var applicationPreferences = applicationPreferences
        modificationFunction(&applicationPreferences)
        self.applicationPreferences = applicationPreferences
    }

    /// Modify an arbitrary stored home by UUID.  If `homeId` matches the active home,
    /// delegates to `modifyActiveHome` so that `currentHomePreferences` stays in sync.
    func modifyStoredHome(_ homeId: UUID, modificationFunction: @MainActor (inout HomePreferences) -> Void) {
        if homeId == activeHomeId {
            modifyActiveHome(modificationFunction: modificationFunction)
        } else {
            var stored = storedHomes
            guard stored[homeId] != nil else { return }
            modificationFunction(&stored[homeId]!)
            storedHomes = stored
        }
    }
}

@MainActor
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

@MainActor
public extension Preferences {
    static func migratePreferences() {
        Preferences.shared.initializeStoredHomes()
        migrateToSharedDefaultsIfRequired()
        migrateToMultipleHomesIfRequired()
    }

    private static func migrateToSharedDefaultsIfRequired() {
        guard !Preferences.shared.didMigrateToSharedDefaults else { return }

        Preferences.shared.modifyActiveHome { currentHomePreferences in
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

        Preferences.shared.idleOff = UserDefaults.standard.object(forKey: "idleOff") as? Bool ?? Preferences.shared.idleOff
        Preferences.shared.sendCrashReports = UserDefaults.standard.object(forKey: "sendCrashReports") as? Bool ?? Preferences.shared.sendCrashReports

        Preferences.shared.didMigrateToSharedDefaults = true
        // this was done implicitly
        Preferences.shared.didMigrateToMultipleHomes = true
    }

    private static func migrateToMultipleHomesIfRequired() {
        guard !Preferences.shared.didMigrateToMultipleHomes else { return }

        migrateToSharedDefaultsIfRequired()

        let oldLocalUrl = sharedDefaults.string(forKey: "localUrl")
        let oldRemoteUrl = sharedDefaults.string(forKey: "remoteUrl")
        let oldUsername = sharedDefaults.string(forKey: "username")
        let oldPassword = sharedDefaults.string(forKey: "password")
        let oldAlwaysSendCreds = sharedDefaults.object(forKey: "alwaysSendCreds") as? Bool
        let oldIgnoreSSL = sharedDefaults.object(forKey: "ignoreSSL") as? Bool

        // Create new configuration
        var newLocalConfiguration = Preferences.shared.currentHomePreferences.localConnectionConfig
        newLocalConfiguration.url = oldLocalUrl ?? newLocalConfiguration.url
        newLocalConfiguration.alwaysSendBasicAuth = oldAlwaysSendCreds ?? newLocalConfiguration.alwaysSendBasicAuth
        newLocalConfiguration.ignoreSSL = oldIgnoreSSL ?? newLocalConfiguration.ignoreSSL

        var newRemoteConfiguration = Preferences.shared.currentHomePreferences.remoteConnectionConfig
        newRemoteConfiguration.url = oldRemoteUrl ?? newRemoteConfiguration.url
        newRemoteConfiguration.username = oldUsername ?? newRemoteConfiguration.username
        newRemoteConfiguration.password = oldPassword ?? newRemoteConfiguration.password
        newRemoteConfiguration.alwaysSendBasicAuth = oldAlwaysSendCreds ?? newRemoteConfiguration.alwaysSendBasicAuth
        newRemoteConfiguration.ignoreSSL = oldIgnoreSSL ?? newRemoteConfiguration.ignoreSSL

        // Save to Preferences
        Preferences.shared.modifyActiveHome { currentHomePreferences in
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

        Preferences.shared.didMigrateToMultipleHomes = true
    }
}

// MARK: All connections

@MainActor
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
