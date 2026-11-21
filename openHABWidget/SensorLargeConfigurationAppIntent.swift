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

struct SensorSmallConfigurationAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Sensor Widget Configuration"
    static let description = IntentDescription("Configure which sensor item to display in the widget.")

    @Parameter(title: "Home")
    var home: Home?

    @Parameter(title: "Sensor Item")
    var item1: SensorWidgetItemEntity?
}

// MARK: - Medium (2 items)

struct SensorMediumConfigurationAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Sensor Widget Configuration"
    static let description = IntentDescription("Configure which sensor items to display in the widget.")

    @Parameter(title: "Home")
    var home: Home?

    @Parameter(title: "Sensor Item 1")
    var item1: SensorMediumWidgetItemEntity?

    @Parameter(title: "Sensor Item 2")
    var item2: SensorMediumWidgetItemEntity?
}

// MARK: - Large (4 items)

struct SensorLargeConfigurationAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Sensor Widget Configuration"
    static let description = IntentDescription("Configure which sensor items to display in the widget.")

    @Parameter(title: "Home")
    var home: Home?

    @Parameter(title: "Sensor Item 1")
    var item1: SensorLargeWidgetItemEntity?

    @Parameter(title: "Sensor Item 2")
    var item2: SensorLargeWidgetItemEntity?

    @Parameter(title: "Sensor Item 3")
    var item3: SensorLargeWidgetItemEntity?

    @Parameter(title: "Sensor Item 4")
    var item4: SensorLargeWidgetItemEntity?
}
