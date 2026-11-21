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
import Foundation

// MARK: - Small / accessory (1 item)

struct SwitchSmallConfigurationAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Switch Widget Configuration"
    static let description = IntentDescription("Configure which switch item to control in the widget.")

    @Parameter(title: "Home")
    var home: Home?

    @Parameter(title: "Switch Item")
    var item1: SwitchWidgetItemEntity?
}

// MARK: - Medium (2 items)

struct SwitchMediumConfigurationAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Switch Widget Configuration"
    static let description = IntentDescription("Configure which switch items to control in the widget.")

    @Parameter(title: "Home")
    var home: Home?

    @Parameter(title: "Switch Item 1")
    var item1: SwitchMediumWidgetItemEntity?

    @Parameter(title: "Switch Item 2")
    var item2: SwitchMediumWidgetItemEntity?
}

// MARK: - Large (4 items)

struct SwitchLargeConfigurationAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Switch Widget Configuration"
    static let description = IntentDescription("Configure which switch items to control in the widget.")

    @Parameter(title: "Home")
    var home: Home?

    @Parameter(title: "Switch Item 1")
    var item1: SwitchLargeWidgetItemEntity?

    @Parameter(title: "Switch Item 2")
    var item2: SwitchLargeWidgetItemEntity?

    @Parameter(title: "Switch Item 3")
    var item3: SwitchLargeWidgetItemEntity?

    @Parameter(title: "Switch Item 4")
    var item4: SwitchLargeWidgetItemEntity?
}
