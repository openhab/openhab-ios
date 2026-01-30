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
/// - Siri phrase suggestions (e.g., "Set switch Kitchen Light from openHAB")
/// - Shortcuts in Spotlight search
/// - Add to Home Screen functionality
/// - Siri Suggestions on lock screen and search
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
            // MARK: - Switch Control
            
            AppShortcut(
                intent: SetSwitchItemIntent(),
                phrases: [
                    "Set \(.applicationName)",
                    "Set switch \(\.$itemEntity) from \(.applicationName)",
                    "Toggle \(\.$itemEntity) in \(.applicationName)",
                    "\(\.$action) \(\.$itemEntity) in \(.applicationName)"
                ],
                shortTitle: "Set Switch",
                systemImageName: "light.beacon.max"
            ),
            
            // MARK: - Dimmer & Roller Shutter Control
            
            AppShortcut(
                intent: SetDimmerRollerValueIntent(),
                phrases: [
                    "Set \(\.$itemEntity) to \(\.$value) in \(.applicationName)",
                    "Adjust \(\.$itemEntity) to \(\.$value) in \(.applicationName)",
                    "Dim \(\.$itemEntity) to \(\.$value) in \(.applicationName)"
                ],
                shortTitle: "Set Dimmer",
                systemImageName: "slider.horizontal.3"
            ),
            
            // MARK: - Color Control
            
            AppShortcut(
                intent: SetColorValueIntent(),
                phrases: [
                    "Set color of \(\.$itemEntity) in \(.applicationName)",
                    "Change color of \(\.$itemEntity) in \(.applicationName)",
                    "Set \(\.$itemEntity) color in \(.applicationName)"
                ],
                shortTitle: "Set Color",
                systemImageName: "paintpalette"
            ),
            
            // MARK: - Get Item State
            
            AppShortcut(
                intent: GetItemStateIntent(),
                phrases: [
                    "Get \(\.$itemEntity) state from \(.applicationName)",
                    "Check \(\.$itemEntity) in \(.applicationName)",
                    "What is \(\.$itemEntity) in \(.applicationName)",
                    "Show \(\.$itemEntity) status in \(.applicationName)"
                ],
                shortTitle: "Get State",
                systemImageName: "info.circle"
            ),
            
            // MARK: - Number Value Control
            
            AppShortcut(
                intent: SetNumberValueIntent(),
                phrases: [
                    "Set \(\.$itemEntity) to \(\.$value) in \(.applicationName)",
                    "Change \(\.$itemEntity) to \(\.$value) in \(.applicationName)"
                ],
                shortTitle: "Set Number",
                systemImageName: "number"
            ),
            
            // MARK: - String Value Control
            
            AppShortcut(
                intent: SetStringValueIntent(),
                phrases: [
                    "Set \(\.$itemEntity) to \(\.$value) in \(.applicationName)",
                    "Update \(\.$itemEntity) to \(\.$value) in \(.applicationName)"
                ],
                shortTitle: "Set Text",
                systemImageName: "text.quote"
            ),
            
            // MARK: - Contact State Control
            
            AppShortcut(
                intent: ContactStateIntent(),
                phrases: [
                    "Set \(\.$itemEntity) to \(\.$state) in \(.applicationName)",
                    "Update contact \(\.$itemEntity) in \(.applicationName)"
                ],
                shortTitle: "Set Contact",
                systemImageName: "sensor"
            )
        ]
    }

    /// The color used for shortcut tiles in the Shortcuts app and Siri interface
    /// Orange matches the openHAB brand color
    static var shortcutTileColor: ShortcutTileColor = .orange
}
