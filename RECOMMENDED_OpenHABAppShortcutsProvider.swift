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
@available(iOS 17.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct OpenHABAppShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        [
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
                systemImageName: "light.beacon.max"
            ),
            
            // MARK: - Get Item State
            // Query the current state of any item
            
            AppShortcut(
                intent: GetItemStateIntent(),
                phrases: [
                    "Get \(\.$itemEntity) in \(.applicationName)",
                    "Check \(\.$itemEntity) in \(.applicationName)",
                    "What is \(\.$itemEntity) in \(.applicationName)"
                ],
                shortTitle: "Get Item State",
                systemImageName: "info.circle"
            ),
            
            // MARK: - Roller Shutter Control - UP Command
            // Separate shortcut for raising/opening roller shutters
            
            AppShortcut(
                intent: SetDimmerRollerValueIntent(),
                phrases: [
                    "Open \(\.$itemEntity) in \(.applicationName)",
                    "Raise \(\.$itemEntity) in \(.applicationName)",
                    "Roll up \(\.$itemEntity) in \(.applicationName)"
                ],
                shortTitle: "Open Shutter",
                systemImageName: "arrow.up.square"
            ),
            
            // MARK: - Roller Shutter Control - DOWN Command
            // Separate shortcut for lowering/closing roller shutters
            
            AppShortcut(
                intent: SetDimmerRollerValueIntent(),
                phrases: [
                    "Close \(\.$itemEntity) in \(.applicationName)",
                    "Lower \(\.$itemEntity) in \(.applicationName)",
                    "Roll down \(\.$itemEntity) in \(.applicationName)"
                ],
                shortTitle: "Close Shutter",
                systemImageName: "arrow.down.square"
            )
        ]
    }

    /// The color used for shortcut tiles in the Shortcuts app and Siri interface
    /// Orange matches the openHAB brand color
    static var shortcutTileColor: ShortcutTileColor = .orange
}
