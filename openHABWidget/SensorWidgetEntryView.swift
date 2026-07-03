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
    struct Slot {
        let item: OpenHABItem
        let homeUUID: UUID
    }

    let date: Date
    let home: Home?
    /// Always contains exactly as many elements as the widget size supports (1, 2, or 4).
    /// nil means the slot is not configured.
    let slots: [Slot?]
}

// MARK: - Shared provider logic

private protocol SensorSlotResolvable {
    var homeId: UUID? { get }
    var item: OpenHABItem { get }
}

private func resolveSlot(entity: (any SensorSlotResolvable)?) async -> SensorEntry.Slot? {
    guard let entity, let homeUUID = entity.homeId else { return nil }
    await WidgetItemRegistry.shared.registerItem(name: entity.item.name, homeId: homeUUID)
    let refreshed = await OpenHABItemCache.instance.getItemUncached(name: entity.item.name, home: homeUUID)
    return SensorEntry.Slot(item: refreshed ?? entity.item, homeUUID: homeUUID)
}

// MARK: - Sample data

private func sampleItem(name: String, label: String, state: String) -> OpenHABItem {
    OpenHABItem(
        name: name, type: "Number:Temperature", state: state, link: "",
        label: label, groupType: nil, stateDescription: nil,
        commandDescription: nil, members: [], category: "temperature", options: nil
    )
}

private let sampleSlots: [SensorEntry.Slot?] = {
    let uuid = UUID()
    return [
        SensorEntry.Slot(item: sampleItem(name: "LivingRoomTemp", label: "Living Room", state: "22.5 °C"), homeUUID: uuid),
        SensorEntry.Slot(item: sampleItem(name: "BedroomHumidity", label: "Bedroom Humidity", state: "65 %"), homeUUID: uuid),
        SensorEntry.Slot(item: sampleItem(name: "OutdoorTemp", label: "Outdoors", state: "18.3 °C"), homeUUID: uuid),
        SensorEntry.Slot(item: sampleItem(name: "PowerUsage", label: "Power Usage", state: "1.2 kW"), homeUUID: uuid)
    ]
}()

// MARK: - Small provider (1 slot)

struct SensorSmallProvider: AppIntentTimelineProvider {
    typealias Intent = SensorSmallConfigurationAppIntent

    func placeholder(in context: Context) -> SensorEntry {
        SensorEntry(date: Date(), home: nil, slots: [sampleSlots[0]])
    }

    func snapshot(for configuration: Intent, in context: Context) async -> SensorEntry {
        context.isPreview ? placeholder(in: context) : await createEntry(for: configuration)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<SensorEntry> {
        let entry = await createEntry(for: configuration)
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func createEntry(for configuration: Intent) async -> SensorEntry {
        let slot = await resolveSlot(entity: configuration.item1 as (any SensorSlotResolvable)?)
        return SensorEntry(date: Date(), home: configuration.home, slots: [slot])
    }
}

// MARK: - Medium provider (2 slots)

struct SensorMediumProvider: AppIntentTimelineProvider {
    typealias Intent = SensorMediumConfigurationAppIntent

    func placeholder(in context: Context) -> SensorEntry {
        SensorEntry(date: Date(), home: nil, slots: Array(sampleSlots.prefix(2)))
    }

    func snapshot(for configuration: Intent, in context: Context) async -> SensorEntry {
        context.isPreview ? placeholder(in: context) : await createEntry(for: configuration)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<SensorEntry> {
        let entry = await createEntry(for: configuration)
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func createEntry(for configuration: Intent) async -> SensorEntry {
        async let s1 = resolveSlot(entity: configuration.item1 as (any SensorSlotResolvable)?)
        async let s2 = resolveSlot(entity: configuration.item2 as (any SensorSlotResolvable)?)
        return await SensorEntry(date: Date(), home: configuration.home, slots: [s1, s2])
    }
}

// MARK: - Large provider (4 slots)

struct SensorLargeProvider: AppIntentTimelineProvider {
    typealias Intent = SensorLargeConfigurationAppIntent

    func placeholder(in context: Context) -> SensorEntry {
        SensorEntry(date: Date(), home: nil, slots: sampleSlots)
    }

    func snapshot(for configuration: Intent, in context: Context) async -> SensorEntry {
        context.isPreview ? placeholder(in: context) : await createEntry(for: configuration)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<SensorEntry> {
        let entry = await createEntry(for: configuration)
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func createEntry(for configuration: Intent) async -> SensorEntry {
        async let s1 = resolveSlot(entity: configuration.item1 as (any SensorSlotResolvable)?)
        async let s2 = resolveSlot(entity: configuration.item2 as (any SensorSlotResolvable)?)
        async let s3 = resolveSlot(entity: configuration.item3 as (any SensorSlotResolvable)?)
        async let s4 = resolveSlot(entity: configuration.item4 as (any SensorSlotResolvable)?)
        return await SensorEntry(date: Date(), home: configuration.home, slots: [s1, s2, s3, s4])
    }
}

// MARK: - State formatting

private func formattedState(for item: OpenHABItem) -> String {
    guard let state = item.state else { return "—" }
    guard let pattern = item.stateDescription?.numberPattern, !pattern.isEmpty else { return state }
    let formatted = state.parseAsNumber(format: pattern).toString(locale: .current)
    return formatted.isEmpty ? state : formatted
}

// MARK: - Unconfigured placeholder

private struct UnconfiguredPlaceholder: View {
    var body: some View {
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

// MARK: - Item Row (used in multi-item layouts)

private struct SensorItemRow: View {
    let slot: SensorEntry.Slot

    var body: some View {
        let item = slot.item
        let label = item.label.isEmpty ? item.name : item.label
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .layoutPriority(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(formattedState(for: item))
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Small Widget (1 item)

struct SensorSmallWidgetView: View {
    let entry: SensorEntry

    var body: some View {
        ZStack(alignment: .center) {
            OpenHABIconOverlay()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(10)

            if let slot = entry.slots.compactMap(\.self).first {
                let item = slot.item
                let label = item.label.isEmpty ? item.name : item.label
                VStack(spacing: 8) {
                    Text(label)
                        .font(.headline)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .padding(.top, 20)
                    Spacer()

                    Text(formattedState(for: item))
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .frame(maxHeight: .infinity)
                .padding()
            } else {
                UnconfiguredPlaceholder()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            }
        }
    }
}

// MARK: - Medium Widget (2 items)

struct SensorMediumWidgetView: View {
    let entry: SensorEntry

    var body: some View {
        ZStack(alignment: .topLeading) {
            OpenHABIconOverlay()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(10)

            let filledSlots = entry.slots.compactMap(\.self)
            if filledSlots.isEmpty {
                UnconfiguredPlaceholder()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filledSlots.indices, id: \.self) { index in
                        SensorItemRow(slot: filledSlots[index])
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        if index < filledSlots.count - 1 {
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Large Widget (4 items)

struct SensorLargeWidgetView: View {
    let entry: SensorEntry

    var body: some View {
        ZStack(alignment: .topLeading) {
            OpenHABIconOverlay()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(14)

            let filledSlots = entry.slots.compactMap(\.self)
            if filledSlots.isEmpty {
                VStack(alignment: .center, spacing: 16) {
                    Image(systemSymbol: .gear)
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Configure Widget")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Long press the widget to configure which sensors to display")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filledSlots.indices, id: \.self) { index in
                        SensorItemRow(slot: filledSlots[index])
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        if index < filledSlots.count - 1 {
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Accessory Views (share small provider / entry)

struct SensorAccessoryCircularView: View {
    let entry: SensorEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let slot = entry.slots.compactMap(\.self).first, slot.item.state != nil {
                VStack(spacing: 2) {
                    Image(systemSymbol: .gaugeWithDotsNeedleBottom50percent)
                        .font(.caption)
                    Text(formattedState(for: slot.item))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                        .multilineTextAlignment(.center)
                }
            } else {
                Image(systemSymbol: .gear)
                    .font(.title3)
            }
        }
    }
}

struct SensorAccessoryRectangularView: View {
    let entry: SensorEntry

    var body: some View {
        if let slot = entry.slots.compactMap(\.self).first {
            let item = slot.item
            let label = item.label.isEmpty ? item.name : item.label
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if item.state != nil {
                    Text(formattedState(for: item))
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
        if let slot = entry.slots.compactMap(\.self).first {
            let item = slot.item
            let label = item.label.isEmpty ? item.name : item.label
            if item.state != nil {
                Text("\(label): \(formattedState(for: item))")
            } else {
                Text(label)
            }
        } else {
            Text("Configure Widget")
        }
    }
}

// MARK: - Unified Entry View (dispatches by family)

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

extension SensorWidgetItemEntity: SensorSlotResolvable {}
extension SensorMediumWidgetItemEntity: SensorSlotResolvable {}
extension SensorLargeWidgetItemEntity: SensorSlotResolvable {}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    SensorSmallWidget()
} timeline: {
    SensorEntry(date: .now, home: nil, slots: [sampleSlots[0]])
}

#Preview("Medium", as: .systemMedium) {
    SensorMediumWidget()
} timeline: {
    SensorEntry(date: .now, home: nil, slots: Array(sampleSlots.prefix(2)))
}

#Preview("Large", as: .systemLarge) {
    SensorLargeWidget()
} timeline: {
    SensorEntry(date: .now, home: nil, slots: sampleSlots)
}

#Preview("Accessory Circular", as: .accessoryCircular) {
    SensorSmallWidget()
} timeline: {
    SensorEntry(date: .now, home: nil, slots: [sampleSlots[0]])
}

#Preview("Accessory Rectangular", as: .accessoryRectangular) {
    SensorSmallWidget()
} timeline: {
    SensorEntry(date: .now, home: nil, slots: [sampleSlots[0]])
}

#Preview("Accessory Inline", as: .accessoryInline) {
    SensorSmallWidget()
} timeline: {
    SensorEntry(date: .now, home: nil, slots: [sampleSlots[0]])
}
