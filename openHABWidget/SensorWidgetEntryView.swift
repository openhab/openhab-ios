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
import OpenHABCore
internal import os.log
internal import SFSafeSymbols
import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct SensorEntry: TimelineEntry {
    let date: Date
    let configuration: SensorConfigurationAppIntent
    let item: OpenHABItem?
    let homeUUID: UUID?
}

// MARK: - Timeline Provider

struct SensorProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SensorEntry {
        // Create a sample sensor item for placeholder
        let sampleItem = OpenHABItem(
            name: "LivingRoomTemperature",
            type: "Number:Temperature",
            state: "22.5 °C",
            link: "",
            label: "Living Room Temperature",
            groupType: nil,
            stateDescription: nil,
            commandDescription: nil,
            members: [],
            category: "temperature",
            options: nil
        )

        return SensorEntry(
            date: Date(),
            configuration: SensorConfigurationAppIntent(),
            item: sampleItem,
            homeUUID: nil
        )
    }

    func snapshot(for configuration: SensorConfigurationAppIntent, in context: Context) async -> SensorEntry {
        // Show placeholder data in widget gallery
        if context.isPreview {
            return placeholder(in: context)
        }
        return await createEntry(for: configuration)
    }

    func timeline(for configuration: SensorConfigurationAppIntent, in context: Context) async -> Timeline<SensorEntry> {
        let entry = await createEntry(for: configuration)

        // Refresh every 5 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func createEntry(for configuration: SensorConfigurationAppIntent) async -> SensorEntry {
        guard let itemEntity = configuration.itemEntity else {
            return SensorEntry(
                date: Date(),
                configuration: configuration,
                item: nil,
                homeUUID: nil
            )
        }

        // Get item from entity
        let item = itemEntity.item
        guard let homeUUID = itemEntity.homeId else {
            return SensorEntry(
                date: Date(),
                configuration: configuration,
                item: item,
                homeUUID: nil
            )
        }

        // Register this item for monitoring in the main app
        await WidgetItemRegistry.shared.registerItem(name: item.name, homeId: homeUUID)

        // Refresh the item state from cache
        let refreshedItem = await OpenHABItemCache.instance.getItemUncached(name: item.name, home: homeUUID)

        return SensorEntry(
            date: Date(),
            configuration: configuration,
            item: refreshedItem ?? item,
            homeUUID: homeUUID
        )
    }
}

// MARK: - Small Widget

struct SensorSmallWidgetView: View {
    let entry: SensorEntry

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 8) {
                if let item = entry.item {
                    let itemLabel = item.label.isEmpty ? item.name : item.label
                    Text(itemLabel)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.top, 20)

                    Spacer()

                    if let itemState = item.state {
                        Text(itemState)
                            .font(.title2)
                            .fontWeight(.bold)
                            .lineLimit(2)
                            .minimumScaleFactor(0.5)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("—")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                } else {
                    VStack {
                        Image(systemSymbol: .gear)
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Configure Widget")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .padding()

            // Widget indicator icon
            Image("openHABIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .opacity(0.5)
                .padding(8)
        }
    }
}

// MARK: - Medium Widget

struct SensorMediumWidgetView: View {
    let entry: SensorEntry

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    if let item = entry.item {
                        let itemLabel = item.label.isEmpty ? item.name : item.label
                        Text(itemLabel)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .padding(.top, 20)

                        Spacer()

                        if let itemState = item.state {
                            Text(itemState)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                        } else {
                            Text("No Data")
                                .font(.title)
                                .foregroundColor(.secondary)
                        }

                        Text(item.type?.rawValue ?? "Sensor")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading) {
                            Image(systemSymbol: .gear)
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("Configure Widget")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .frame(maxHeight: .infinity)
            .padding()

            // Widget indicator icon
            Image("openHABIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .opacity(0.5)
                .padding(8)
        }
    }
}

// MARK: - Large Widget

struct SensorLargeWidgetView: View {
    let entry: SensorEntry

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 16) {
                if let item = entry.item {
                    let itemLabel = item.label.isEmpty ? item.name : item.label
                    Text(itemLabel)
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top, 20)

                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Value")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let itemState = item.state {
                                Text(itemState)
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                            } else {
                                Text("—")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()
                    }

                    HStack {
                        Image(systemSymbol: sensorIcon(for: item.type))
                            .font(.caption)
                        Text(item.type?.rawValue ?? "Sensor")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)

                    Spacer()
                } else {
                    VStack(alignment: .center, spacing: 16) {
                        Image(systemSymbol: .gear)
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Configure Widget")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Long press the widget to configure which sensor to display")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
            .padding()

            // Widget indicator icon
            Image("openHABIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .opacity(0.5)
                .padding(12)
        }
    }

    private func sensorIcon(for type: OpenHABItem.ItemType?) -> SFSymbol {
        guard let type else { return .gaugeWithDotsNeedleBottom50percent }
        switch type {
        case .number, .numberWithDimension:
            return .gaugeWithDotsNeedleBottom50percent
        case .stringItem:
            return .textQuote
        default:
            return .gaugeWithDotsNeedleBottom50percent
        }
    }
}

// MARK: - Accessory Views

struct SensorAccessoryCircularView: View {
    let entry: SensorEntry

    var body: some View {
        if let item = entry.item, let itemState = item.state {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemSymbol: .gaugeWithDotsNeedleBottom50percent)
                        .font(.caption)
                    Text(itemState)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemSymbol: .gear)
                    .font(.title3)
            }
        }
    }
}

struct SensorAccessoryRectangularView: View {
    let entry: SensorEntry

    var body: some View {
        if let item = entry.item {
            let itemLabel = item.label.isEmpty ? item.name : item.label
            VStack(alignment: .leading, spacing: 2) {
                Text(itemLabel)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let itemState = item.state {
                    Text(itemState)
                        .font(.body)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                } else {
                    Text("No Data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            Text("Configure")
                .font(.caption)
        }
    }
}

struct SensorAccessoryInlineView: View {
    let entry: SensorEntry

    var body: some View {
        if let item = entry.item {
            let itemLabel = item.label.isEmpty ? item.name : item.label
            if let itemState = item.state {
                Text("\(itemLabel): \(itemState)")
            } else {
                Text(itemLabel)
            }
        } else {
            Text("Configure Widget")
        }
    }
}

// MARK: - Widget View

struct SensorWidgetEntryView: View {
    var entry: SensorEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SensorSmallWidgetView(entry: entry)
        case .systemMedium:
            SensorMediumWidgetView(entry: entry)
        case .systemLarge:
            SensorLargeWidgetView(entry: entry)
        case .accessoryCircular:
            SensorAccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            SensorAccessoryRectangularView(entry: entry)
        case .accessoryInline:
            SensorAccessoryInlineView(entry: entry)
        default:
            SensorSmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    SensorWidgetView()
} timeline: {
    SensorEntry(
        date: .now,
        configuration: SensorConfigurationAppIntent(),
        item: OpenHABItem(
            name: "LivingRoomTemperature",
            type: "Number:Temperature",
            state: "22.5 °C",
            link: "",
            label: "Living Room Temperature",
            groupType: nil,
            stateDescription: nil,
            commandDescription: nil,
            members: [],
            category: "temperature",
            options: nil
        ),
        homeUUID: nil
    )
}
