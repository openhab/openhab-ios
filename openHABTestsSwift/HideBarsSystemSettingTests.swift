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
@testable import openHAB
import Testing

struct HideBarsSystemSettingTests {
    @Test func theSettingsAppShowsTheAppValueBeforeItHasWrittenAnything() {
        let resolution = HideBarsSystemSetting.resolve(app: true, system: nil)
        #expect(resolution == .init(value: true, updatesApp: false, updatesSystem: true))
    }

    @Test(arguments: [true, false])
    func nothingChangesWhenBothAgree(value: Bool) {
        let resolution = HideBarsSystemSetting.resolve(app: value, system: value)
        #expect(resolution == .init(value: value, updatesApp: false, updatesSystem: false))
    }

    @Test(arguments: [true, false])
    func aChangeInTheSettingsAppWins(system: Bool) {
        let resolution = HideBarsSystemSetting.resolve(app: !system, system: system)
        #expect(resolution == .init(value: system, updatesApp: true, updatesSystem: false))
    }

    @Test func writeStoresTheValueUnderTheKeyOfTheBundle() throws {
        let suite = "HideBarsSystemSettingTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        HideBarsSystemSetting.write(true, to: defaults)
        #expect(defaults.object(forKey: "hide_bars_preference") as? Bool == true)
    }

    /// The key in the code and in the bundle must be the same, or the switch does nothing.
    @Test func bundleUsesTheSameKey() throws {
        let bundleURL = try #require(Bundle.main.url(forResource: "Settings", withExtension: "bundle"))
        let plistURL = bundleURL.appendingPathComponent("Root.plist")
        let plist = try #require(NSDictionary(contentsOf: plistURL))
        let specifiers = try #require(plist["PreferenceSpecifiers"] as? [[String: Any]])
        let keys = specifiers.compactMap { $0["Key"] as? String }
        #expect(keys.contains(HideBarsSystemSetting.key))
    }
}
