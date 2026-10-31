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

import Foundation
import OpenHABCore

/// The "Hide Status and Navigation Bar" switch in the iOS Settings app (`Settings.bundle`), as a way
/// out for a user who hid the bars and cannot get at the in-app setting.
///
/// The Settings app writes to the app's standard defaults, while the app keeps its own settings in
/// the app group's (`Preferences`), so the two are reconciled. A change in the app writes both,
/// so a difference between them means the user changed the switch in the Settings app.
enum HideBarsSystemSetting {
    struct Resolution: Equatable {
        let value: Bool
        let updatesApp: Bool
        let updatesSystem: Bool
    }

    /// The key in `Settings.bundle/Root.plist`.
    static let key = "hide_bars_preference"

    /// `system` is nil until the Settings app or the app has written the switch once.
    static func resolve(app: Bool, system: Bool?) -> Resolution {
        guard let system else {
            return Resolution(value: app, updatesApp: false, updatesSystem: true)
        }
        guard system != app else {
            return Resolution(value: app, updatesApp: false, updatesSystem: false)
        }
        return Resolution(value: system, updatesApp: true, updatesSystem: false)
    }

    /// Brings the two in line and returns the value that holds now.
    static func sync(preferences: Preferences = .shared, defaults: UserDefaults = .standard) async -> Bool {
        let resolution = await resolve(app: preferences.hideStatusBar, system: defaults.object(forKey: key) as? Bool)
        if resolution.updatesApp {
            await preferences.setHideStatusBar(resolution.value)
        }
        if resolution.updatesSystem {
            defaults.set(resolution.value, forKey: key)
        }
        return resolution.value
    }

    /// The app's own change, so the Settings app shows it and `sync` does not take it for a change there.
    static func write(_ value: Bool, to defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: key)
    }
}
