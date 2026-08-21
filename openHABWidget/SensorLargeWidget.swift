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

import SwiftUI
import WidgetKit

// MARK: - Small + accessory widget (1 item)

struct SensorSmallWidget: Widget {
    let kind = "OpenHABSensorWidgetSmall"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SensorSmallConfigurationAppIntent.self,
            provider: SensorSmallProvider()
        ) { entry in
            SensorWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("openHAB Sensor")
        .description("Display an openHAB sensor value")
        .supportedFamilies([
            .systemSmall,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
        .widgetContentMarginsDisabled()
    }
}

// MARK: - Medium widget (2 items)

struct SensorMediumWidget: Widget {
    let kind = "OpenHABSensorWidgetMedium"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SensorMediumConfigurationAppIntent.self,
            provider: SensorMediumProvider()
        ) { entry in
            SensorWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("openHAB Sensor")
        .description("Display two openHAB sensor values")
        .supportedFamilies([.systemMedium])
        .widgetContentMarginsDisabled()
    }
}

// MARK: - Large widget (4 items)

struct SensorLargeWidget: Widget {
    let kind = "OpenHABSensorWidgetLarge"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SensorLargeConfigurationAppIntent.self,
            provider: SensorLargeProvider()
        ) { entry in
            SensorWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("openHAB Sensor")
        .description("Display up to four openHAB sensor values")
        .supportedFamilies([.systemLarge])
        .widgetContentMarginsDisabled()
    }
}
