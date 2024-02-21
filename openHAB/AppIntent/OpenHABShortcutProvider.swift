// Copyright (c) 2010-2024 Contributors to the openHAB project
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

/// - Tag: AppShortcuts
@available(iOS 17.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct OpenHABAppShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SetSwitchState(),
            phrases: [
                "Set \(.applicationName)",
                "Set switch \(\.$item) from \(.applicationName)"
            ],
            shortTitle: "Set switch"
        )
    }
    static var shortcutTileColor: ShortcutTileColor = .orange
}
