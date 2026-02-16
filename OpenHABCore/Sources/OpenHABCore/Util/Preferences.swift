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

import AsyncAlgorithms
import os.log
import SwiftUI

// Thread-safe access to UserDefaults - still needs main actor due to UserDefaults not being Sendable
private nonisolated(unsafe) let sharedDefaults = UserDefaults(suiteName: "group.org.openhab.app")!

@propertyWrapper
public struct UserDefault<T: Sendable> {
    private let key: String
    private let defaultValue: T
    private let isHomeProperty: Bool
    private let subject: CurrentValueSubject<T, Never>
    private let channel: AsyncChannel<T>

    public var wrappedValue: T {
        get {
            PreferencesAccess.getPreference(key: key, defaultValue: defaultValue, encoder: { $0 }, decoder: { $0 as? T })
        }
        set {
            PreferencesAccess.preferenceChanged(newValue: newValue, key: key, isHomeProperty: isHomeProperty, subject: subject, channel: channel) { $0 }
        }
    }

    public var projectedValue: AnyPublisher<T, Never> {
        subject.eraseToAnyPublisher()
    }
    
    public var asyncValues: AsyncChannel<T> {
        channel
    }

    public init(_ key: String, defaultValue: T, isHomeProperty: Bool = false) {
        self.key = key
        self.defaultValue = defaultValue
        self.isHomeProperty = isHomeProperty
        let currentValue = PreferencesAccess.getPreference(key: key, defaultValue: defaultValue, encoder: { $0 }, decoder: { $0 as? T })
        subject = CurrentValueSubject<T, Never>(currentValue)
        channel = AsyncChannel<T>()
    }
}

@propertyWrapper
public struct UserDefaultObject<T: Codable & Sendable> {
    private let key: String
    private let defaultValue: T
    private let isHomeProperty: Bool
    private let subject: CurrentValueSubject<T, Never>
    private let channel: AsyncChannel<T>

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
            PreferencesAccess.preferenceChanged(newValue: newValue, key: key, isHomeProperty: isHomeProperty, subject: subject, channel: channel, converter: objectEncoder)
        }
    }

    public var projectedValue: AnyPublisher<T, Never> {
        subject.eraseToAnyPublisher()
    }
    
    public var asyncValues: AsyncChannel<T> {
        channel
    }

    init(_ key: String, defaultValue: T, isHomeProperty: Bool = false) {
        self.key = key
        self.defaultValue = defaultValue
        self.isHomeProperty = isHomeProperty

        // Combine publication
        let currentValue = PreferencesAccess.getPreference(key: key, defaultValue: defaultValue, encoder: objectEncoder, decoder: objectDecoder)
        subject = CurrentValueSubject(currentValue)
        channel = AsyncChannel<T>()
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
    public var lastSelectedTab = "main"
    public var tabConfiguration = TabEntry.defaultConfiguration

    fileprivate init(id: UUID) {
        self.id = id
    }
}

public struct TabEntry: Codable, Equatable, Hashable, Sendable {
    public var id: String
    public var enabled: Bool

    public init(id: String, enabled: Bool) {
        self.id = id
        self.enabled = enabled
    }

    public static let defaultConfiguration: [TabEntry] = [
        TabEntry(id: "main", enabled: true),
        TabEntry(id: "sitemaps", enabled: true),
        TabEntry(id: "tiles", enabled: true),
        TabEntry(id: "system", enabled: true)
    ]
}

public struct ApplicationPreferences: Codable, Equatable, Sendable {
    public var showSearchField = true
    public var sendCrashReports = false
    public var idleOff = false
    public var hideStatusBar = false
}

public struct ScreenSaverPreferences: Codable, Equatable, Sendable {
    public var isEnabled = false
    public var showsTime = true
    public var showsDate = true
    public var idleInterval = 120.0
    public var movementInterval = 8.0
    public var fontName = ""
    public var timeFontRatio = 0.2
    public var dateFontRatio = 0.4
    public var enableDimming = true
    public var dimLevel = 0.3
    public var showsSeconds = false
    public var use24Hour = false
    public var fadeDuration = 2.0
    public var restoreBrightness = true
    public var wakeBrightness = 1.0
}

// MARK: Retrieving preference from user defaults, reacting to preference change

// MARK: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

// MARK: !!

// MARK: When making changes to Preferences, always consider a migration for existing users. Otherwise, they risk to loose their existing preferences.

// MARK: !!

// MARK: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

private enum PreferencesAccess {
    fileprivate static func getPreference<T>(key: String, defaultValue: T, encoder: (T) -> (some Sendable)?, decoder: (Any?) -> T?) -> T {
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

    fileprivate static func preferenceChanged<T>(newValue: T, key: String, isHomeProperty: Bool, subject: CurrentValueSubject<T, Never>, channel: AsyncChannel<T>, sanitize: (T) -> (T?) = { $0 }, converter: (T) -> (some Sendable)?) {
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
        
        // Send to AsyncChannel
        Task {
            await channel.send(sanitized)
        }
    }
}

public actor Preferences {
    public static let shared = Preferences()

    private static let defaultHomeId = UUID()

    /// the currently applied settings set from storedHomes
    @UserDefaultObject("currentHomePreferences", defaultValue: HomePreferences(id: defaultHomeId))
    public private(set) var currentHomePreferences: HomePreferences

    @UserDefaultObject(
        "applicationPreferences",
        defaultValue:
        ApplicationPreferences()
    )
    public private(set) var applicationPreferences: ApplicationPreferences

    @UserDefaultObject(
        "screensaverPreferences",
        defaultValue:
        ScreenSaverPreferences()
    )
    public private(set) var screensaverPreferences: ScreenSaverPreferences

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

    @UserDefault("didMigrateScreenSaverPreferences", defaultValue: false)
    private var didMigrateScreenSaverPreferences: Bool

    @UserDefault("didMigrateApplicationPreferences", defaultValue: false)
    private var didMigrateApplicationPreferences: Bool

    private var internalPreferenceChangeOngoing = false

    private func internalPreferenceChange(_ change: () -> Void) {
        internalPreferenceChangeOngoing = true
        change()
        internalPreferenceChangeOngoing = false
    }
    
    // MARK: - AsyncChannel Access
    
    /// Access the AsyncChannel for currentHomePreferences
    public var currentHomePreferencesChannel: AsyncChannel<HomePreferences> {
        _currentHomePreferences.asyncValues
    }
    
    /// Access the AsyncChannel for applicationPreferences
    public var applicationPreferencesChannel: AsyncChannel<ApplicationPreferences> {
        _applicationPreferences.asyncValues
    }
    
    /// Access the AsyncChannel for screensaverPreferences
    public var screensaverPreferencesChannel: AsyncChannel<ScreenSaverPreferences> {
        _screensaverPreferences.asyncValues
    }
    
    /// Access the AsyncChannel for storedHomes
    public var storedHomesChannel: AsyncChannel<[UUID: HomePreferences]> {
        _storedHomes.asyncValues
    }
    
    // Setter methods for actor-isolated properties (used in migration)
    func setDidMigrateToSharedDefaults(_ value: Bool) {
        didMigrateToSharedDefaults = value
    }
    
    func setDidMigrateToMultipleHomes(_ value: Bool) {
        didMigrateToMultipleHomes = value
    }
    
    func setDidMigrateScreenSaverPreferences(_ value: Bool) {
        didMigrateScreenSaverPreferences = value
    }
    
    func setDidMigrateApplicationPreferences(_ value: Bool) {
        didMigrateApplicationPreferences = value
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
        let homeId = activeHomeId
        all[homeId] = currentHomePreferences
        storedHomes = all
        Logger.preferences.debug("Stored preferences for current home \(homeId.uuidString)")
    }

    func modifyActiveHome(modificationFunction: @Sendable (inout HomePreferences) -> Void) {
        var homePreferences = currentHomePreferences
        modificationFunction(&homePreferences)
        currentHomePreferences = homePreferences
        storeActiveHome()
    }

    func modifyApplicationPreferences(modificationFunction: @Sendable (inout ApplicationPreferences) -> Void) {
        var applicationPreferences = applicationPreferences
        modificationFunction(&applicationPreferences)
        self.applicationPreferences = applicationPreferences
    }

    func modifyScreenSaverPreferences(modificationFunction: @Sendable (inout ScreenSaverPreferences) -> Void) {
        var screensaverPreferences = screensaverPreferences
        modificationFunction(&screensaverPreferences)
        self.screensaverPreferences = screensaverPreferences
    }

    func setCurrentWebViewPath(_ path: String) {
        currentWebViewPath = path
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
    static func migratePreferences() async {
        await Preferences.shared.initializeStoredHomes()
        await migrateToSharedDefaultsIfRequired()
        await migrateToMultipleHomesIfRequired()
        await migrateApplicationPreferencesIfRequired()
        await migrateScreenSaverPreferencesIfRequired()
    }

    private static func migrateToSharedDefaultsIfRequired() async {
        guard await !Preferences.shared.didMigrateToSharedDefaults else { return }

        await Preferences.shared.modifyActiveHome { currentHomePreferences in
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

        await Preferences.shared.setDidMigrateToSharedDefaults(true)
        // this was done implicitly
        await Preferences.shared.setDidMigrateToMultipleHomes(true)
    }

    private static func migrateToMultipleHomesIfRequired() async {
        guard await !Preferences.shared.didMigrateToMultipleHomes else { return }

        await migrateToSharedDefaultsIfRequired()

        let oldLocalUrl = sharedDefaults.string(forKey: "localUrl")
        let oldRemoteUrl = sharedDefaults.string(forKey: "remoteUrl")
        let oldUsername = sharedDefaults.string(forKey: "username")
        let oldPassword = sharedDefaults.string(forKey: "password")
        let oldAlwaysSendCreds = sharedDefaults.object(forKey: "alwaysSendCreds") as? Bool
        let oldIgnoreSSL = sharedDefaults.object(forKey: "ignoreSSL") as? Bool

        // Save to Preferences
        await Preferences.shared.modifyActiveHome { currentHomePreferences in
            // Create new configuration inside the closure to avoid capture issues
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

        await Preferences.shared.setDidMigrateToMultipleHomes(true)
    }

    private static func migrateApplicationPreferencesIfRequired() async {
        guard await !Preferences.shared.didMigrateApplicationPreferences else { return }

        // Check if old preferences exist in UserDefaults
        let oldSendCrashReports = sharedDefaults.object(forKey: "sendCrashReports") as? Bool
        let oldIdleOff = sharedDefaults.object(forKey: "idleOff") as? Bool
        let oldHideStatusBar = sharedDefaults.object(forKey: "hideStatusBar") as? Bool

        // Only migrate if at least one old preference exists
        if oldSendCrashReports != nil || oldIdleOff != nil || oldHideStatusBar != nil {
            await Preferences.shared.modifyApplicationPreferences { prefs in
                if let oldSendCrashReports { prefs.sendCrashReports = oldSendCrashReports }
                if let oldIdleOff { prefs.idleOff = oldIdleOff }
                if let oldHideStatusBar { prefs.hideStatusBar = oldHideStatusBar }
            }

            Logger.preferences.info("Migrated application preferences from individual keys to ApplicationPreferences struct")

            // Clean up old keys
            sharedDefaults.removeObject(forKey: "sendCrashReports")
            sharedDefaults.removeObject(forKey: "idleOff")
            sharedDefaults.removeObject(forKey: "hideStatusBar")
        }

        await Preferences.shared.setDidMigrateApplicationPreferences(true)
    }

    private static func migrateScreenSaverPreferencesIfRequired() async {
        guard await !Preferences.shared.didMigrateScreenSaverPreferences else { return }

        // Check if old preferences exist in UserDefaults
        let oldEnabled = sharedDefaults.object(forKey: "screensaverEnabled") as? Bool
        let oldShowsTime = sharedDefaults.object(forKey: "screensaverShowsTime") as? Bool
        let oldShowsDate = sharedDefaults.object(forKey: "screensaverShowsDate") as? Bool
        let oldIdleInterval = sharedDefaults.object(forKey: "screensaverIdleInterval") as? Double
        let oldMovementInterval = sharedDefaults.object(forKey: "screensaverMovementInterval") as? Double
        let oldFontName = sharedDefaults.string(forKey: "screensaverFontName")
        let oldTimeFontRatio = sharedDefaults.object(forKey: "screensaverTimeFontRatio") as? Double
        let oldDateFontRatio = sharedDefaults.object(forKey: "screensaverDateFontRatio") as? Double
        let oldEnableDimming = sharedDefaults.object(forKey: "screensaverEnableDimming") as? Bool
        let oldDimLevel = sharedDefaults.object(forKey: "screensaverDimLevel") as? Double
        let oldShowsSeconds = sharedDefaults.object(forKey: "screensaverShowsSeconds") as? Bool
        let oldUse24Hour = sharedDefaults.object(forKey: "screensaverUse24Hour") as? Bool
        let oldFadeDuration = sharedDefaults.object(forKey: "screensaverFadeDuration") as? Double
        let oldRestoreBrightness = sharedDefaults.object(forKey: "screensaverRestoreBrightness") as? Bool
        let oldWakeBrightness = sharedDefaults.object(forKey: "screensaverWakeBrightness") as? Double

        // Only migrate if at least one old preference exists
        if oldEnabled != nil || oldShowsTime != nil || oldIdleInterval != nil {
            await Preferences.shared.modifyScreenSaverPreferences { prefs in
                if let oldEnabled { prefs.isEnabled = oldEnabled }
                if let oldShowsTime { prefs.showsTime = oldShowsTime }
                if let oldShowsDate { prefs.showsDate = oldShowsDate }
                if let oldIdleInterval { prefs.idleInterval = oldIdleInterval }
                if let oldMovementInterval { prefs.movementInterval = oldMovementInterval }
                if let oldFontName { prefs.fontName = oldFontName }
                if let oldTimeFontRatio { prefs.timeFontRatio = oldTimeFontRatio }
                if let oldDateFontRatio { prefs.dateFontRatio = oldDateFontRatio }
                if let oldEnableDimming { prefs.enableDimming = oldEnableDimming }
                if let oldDimLevel { prefs.dimLevel = oldDimLevel }
                if let oldShowsSeconds { prefs.showsSeconds = oldShowsSeconds }
                if let oldUse24Hour { prefs.use24Hour = oldUse24Hour }
                if let oldFadeDuration { prefs.fadeDuration = oldFadeDuration }
                if let oldRestoreBrightness { prefs.restoreBrightness = oldRestoreBrightness }
                if let oldWakeBrightness { prefs.wakeBrightness = oldWakeBrightness }
            }

            Logger.preferences.info("Migrated screen saver preferences from individual keys to ScreenSaverPreferences struct")

            // Clean up old keys (optional, but keeps UserDefaults tidy)
            sharedDefaults.removeObject(forKey: "screensaverEnabled")
            sharedDefaults.removeObject(forKey: "screensaverShowsTime")
            sharedDefaults.removeObject(forKey: "screensaverShowsDate")
            sharedDefaults.removeObject(forKey: "screensaverIdleInterval")
            sharedDefaults.removeObject(forKey: "screensaverMovementInterval")
            sharedDefaults.removeObject(forKey: "screensaverFontName")
            sharedDefaults.removeObject(forKey: "screensaverTimeFontRatio")
            sharedDefaults.removeObject(forKey: "screensaverDateFontRatio")
            sharedDefaults.removeObject(forKey: "screensaverEnableDimming")
            sharedDefaults.removeObject(forKey: "screensaverDimLevel")
            sharedDefaults.removeObject(forKey: "screensaverShowsSeconds")
            sharedDefaults.removeObject(forKey: "screensaverUse24Hour")
            sharedDefaults.removeObject(forKey: "screensaverFadeDuration")
            sharedDefaults.removeObject(forKey: "screensaverRestoreBrightness")
            sharedDefaults.removeObject(forKey: "screensaverWakeBrightness")
        }

        await Preferences.shared.setDidMigrateScreenSaverPreferences(true)
    }
}

// MARK: All connections

public extension Preferences {
    func getNotificationConnection() -> ConnectionConfiguration? {
        getNotificationConnection(of: [currentHomePreferences.remoteConnectionConfig])
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

// MARK: - SwiftUI Observable Wrapper

/// A @MainActor observable wrapper for Preferences that can be used in SwiftUI views
@MainActor
@Observable
public final class PreferencesObserver {
    public static let shared = PreferencesObserver()

    public private(set) var currentHomePreferences: HomePreferences
    public private(set) var applicationPreferences: ApplicationPreferences
    public private(set) var screensaverPreferences: ScreenSaverPreferences

    private var currentHomeTask: Task<Void, Never>?
    private var applicationTask: Task<Void, Never>?
    private var screensaverTask: Task<Void, Never>?

    private init() {
        // Initialize with default values - will be updated immediately by channels
        self.currentHomePreferences = HomePreferences(id: UUID())
        self.applicationPreferences = ApplicationPreferences()
        self.screensaverPreferences = ScreenSaverPreferences()

        // Bootstrap initial values and start listeners
        Task { [weak self] in
            guard let self else { return }
            // Fetch initial values from the actor
            let initialHome = await Preferences.shared.currentHomePreferences
            let initialApp = await Preferences.shared.applicationPreferences
            let initialScreen = await Preferences.shared.screensaverPreferences

            // Apply initial values on the main actor
            self.currentHomePreferences = initialHome
            self.applicationPreferences = initialApp
            self.screensaverPreferences = initialScreen

            // Start listening to async channels
            self.currentHomeTask = Task { [weak self] in
                guard let self else { return }
                let channel = await Preferences.shared.currentHomePreferencesChannel
                for await value in channel {
                    await MainActor.run { self.currentHomePreferences = value }
                }
            }

            self.applicationTask = Task { [weak self] in
                guard let self else { return }
                let channel = await Preferences.shared.applicationPreferencesChannel
                for await value in channel {
                    await MainActor.run { self.applicationPreferences = value }
                }
            }

            self.screensaverTask = Task { [weak self] in
                guard let self else { return }
                let channel = await Preferences.shared.screensaverPreferencesChannel
                for await value in channel {
                    await MainActor.run { self.screensaverPreferences = value }
                }
            }
        }
    }

    @MainActor
    deinit {
        currentHomeTask?.cancel()
        applicationTask?.cancel()
        screensaverTask?.cancel()
    }

    /// Get notification connection for current home
    public func getNotificationConnection() async -> ConnectionConfiguration? {
        await Preferences.shared.getNotificationConnection()
    }
}

