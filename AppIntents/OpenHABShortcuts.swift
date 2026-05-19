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

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct OpenHABShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SetSwitchItemIntent(),
            phrases: [
                "Set a switch in \(.applicationName)",
                "Toggle a switch in \(.applicationName)"
            ],
            shortTitle: "Set Switch",
            systemImageName: "switch.2"
        )
        AppShortcut(
            intent: GetItemStateIntent(),
            phrases: ["Get item state in \(.applicationName)"],
            shortTitle: "Get Item State",
            systemImageName: "info.circle"
        )
        AppShortcut(
            intent: SetDimmerRollerValueIntent(),
            phrases: [
                "Set dimmer in \(.applicationName)",
                "Set roller shutter in \(.applicationName)"
            ],
            shortTitle: "Set Dimmer / Roller",
            systemImageName: "slider.horizontal.3"
        )
        AppShortcut(
            intent: SetColorValueIntent(),
            phrases: ["Set color light in \(.applicationName)"],
            shortTitle: "Set Color",
            systemImageName: "paintpalette"
        )
        AppShortcut(
            intent: SetNumberValueIntent(),
            phrases: ["Set number value in \(.applicationName)"],
            shortTitle: "Set Number",
            systemImageName: "number"
        )
        AppShortcut(
            intent: SetPlayerValueIntent(),
            phrases: ["Control player in \(.applicationName)"],
            shortTitle: "Control Player",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: SetStringValueIntent(),
            phrases: ["Set text value in \(.applicationName)"],
            shortTitle: "Set Text",
            systemImageName: "character.cursor.ibeam"
        )
        AppShortcut(
            intent: SetDateTimeValueIntent(),
            phrases: ["Set date and time in \(.applicationName)"],
            shortTitle: "Set Date & Time",
            systemImageName: "calendar.badge.clock"
        )
        AppShortcut(
            intent: SetLocationValueIntent(),
            phrases: ["Set location in \(.applicationName)"],
            shortTitle: "Set Location",
            systemImageName: "location"
        )
        AppShortcut(
            intent: ContactStateIntent(),
            phrases: ["Set contact state in \(.applicationName)"],
            shortTitle: "Set Contact State",
            systemImageName: "sensor"
        )
    }
}
