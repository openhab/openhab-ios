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

import AppIntents
internal import SFSafeSymbols

/// App Shortcuts Provider for openHAB app
///
/// This provider registers app shortcuts with iOS, enabling:
/// - Siri phrase suggestions (e.g., "Toggle Kitchen Light in openHAB")
/// - Shortcuts in Spotlight search
/// - Add to Home Screen functionality
/// - Siri Suggestions on lock screen and search
///
/// ## Design Note
/// Due to iOS AppShortcuts limitation of one parameter per phrase,
/// shortcuts are designed for specific, common actions:
/// - Toggle switch items (most common switch operation)
/// - Get item state (universal query)
/// - Open/Close roller shutters (specific directional commands)
///
/// The action is embedded in the phrase itself since we can only
/// pass the item name as a parameter.
///
/// ## SF Symbol Names
/// Apple's AppShortcut requires literal strings for `systemImageName` -
/// constants and SFSafeSymbols cannot be used due to compile-time metadata extraction.
/// Symbol names use SF Symbols naming convention (e.g., "light.beacon.max").
/// Reference: https://developer.apple.com/sf-symbols/
///
/// ## Note
/// This file was present in PR #742 but was missing from PR #1028.
/// Adding it restores iOS app shortcuts functionality.
///
/// ## Usage
/// This struct is automatically discovered by iOS at build time.
/// No explicit registration is required - just having this file
/// in the app target is sufficient.
///
/// ## References
/// - Apple Documentation: https://developer.apple.com/documentation/appintents/app-shortcuts
/// - PR #742: Original implementation
/// - PR #1028: Enhanced intent implementations
struct OpenHABAppShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // MARK: - Switch Control - Toggle Action

        // Note: Since AppShortcuts only allow one parameter per phrase,
        // the action (toggle) is embedded in the phrase itself

        AppShortcut(
            intent: SetSwitchItemIntent(),
            phrases: [
                "Toggle \(\.$itemEntity) in \(.applicationName)",
                "Toggle switch \(\.$itemEntity) in \(.applicationName)"
            ],
            shortTitle: "Toggle Switch",
            systemImageName: "light.beacon.max" // SFSymbol: .lightBeaconMax
        )

        // Roller shutter and dimmer shortcuts are omitted: SetDimmerRollerValueIntent
        // requires a value: Int parameter not present in the phrase, so Siri would
        // prompt "what value?" after the phrase — poor UX. Dedicated open/close
        // intents (no value parameter) would be needed to add shutter shortcuts.
    }

    /// The color used for shortcut tiles in the Shortcuts app and Siri interface
    /// Orange matches the openHAB brand color
    static let shortcutTileColor: ShortcutTileColor = .orange
}
