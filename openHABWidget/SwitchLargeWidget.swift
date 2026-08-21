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

struct SwitchSmallWidget: Widget {
    let kind = "OpenHABSwitchWidgetSmall"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SwitchSmallConfigurationAppIntent.self,
            provider: SwitchSmallProvider()
        ) { entry in
            SwitchWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("openHAB Switch")
        .description("Control an openHAB switch item")
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

struct SwitchMediumWidget: Widget {
    let kind = "OpenHABSwitchWidgetMedium"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SwitchMediumConfigurationAppIntent.self,
            provider: SwitchMediumProvider()
        ) { entry in
            SwitchWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("openHAB Switch")
        .description("Control two openHAB switch items")
        .supportedFamilies([.systemMedium])
        .widgetContentMarginsDisabled()
    }
}

// MARK: - Large widget (4 items)

struct SwitchLargeWidget: Widget {
    let kind = "OpenHABSwitchWidgetLarge"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SwitchLargeConfigurationAppIntent.self,
            provider: SwitchLargeProvider()
        ) { entry in
            SwitchWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("openHAB Switch")
        .description("Control up to four openHAB switch items")
        .supportedFamilies([.systemLarge])
        .widgetContentMarginsDisabled()
    }
}
