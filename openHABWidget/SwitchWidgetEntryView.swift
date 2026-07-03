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

struct SwitchEntry: TimelineEntry {
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

// MARK: - Helper Functions

private func createToggleIntent(item: OpenHABItem, homeUUID: UUID, home: Home) -> SetSwitchItemIntent {
    let intent = SetSwitchItemIntent()
    intent.itemEntity = SwitchItemEntity(item, homeId: homeUUID, homeName: home.displayString)
    intent.action = .toggle
    intent.home = home
    return intent
}

private func sampleItem(name: String, label: String, state: String) -> OpenHABItem {
    OpenHABItem(
        name: name, type: "Switch", state: state, link: "",
        label: label, groupType: nil, stateDescription: nil,
        commandDescription: nil, members: [], category: "light", options: nil
    )
}

// MARK: - Shared provider logic

/// Common interface for all switch widget entity types, used so resolveSlot
/// can be a single function regardless of which configuration intent the entity
/// was declared in.
private protocol SwitchSlotResolvable {
    var homeId: UUID? { get }
    var item: OpenHABItem { get }
}

private func resolveSlot(entity: (any SwitchSlotResolvable)?) async -> SwitchEntry.Slot? {
    guard let entity, let homeUUID = entity.homeId else { return nil }
    await WidgetItemRegistry.shared.registerItem(name: entity.item.name, homeId: homeUUID)
    let refreshed = await OpenHABItemCache.instance.getItemUncached(name: entity.item.name, home: homeUUID)
    return SwitchEntry.Slot(item: refreshed ?? entity.item, homeUUID: homeUUID)
}

private let sampleSlots: [SwitchEntry.Slot?] = {
    let uuid = UUID()
    return [
        SwitchEntry.Slot(item: sampleItem(name: "LivingRoomLight", label: "Living Room", state: "ON"), homeUUID: uuid),
        SwitchEntry.Slot(item: sampleItem(name: "BedroomLight", label: "Bedroom", state: "OFF"), homeUUID: uuid),
        SwitchEntry.Slot(item: sampleItem(name: "KitchenLight", label: "Kitchen", state: "ON"), homeUUID: uuid),
        SwitchEntry.Slot(item: sampleItem(name: "HallwayLight", label: "Hallway", state: "OFF"), homeUUID: uuid)
    ]
}()

// MARK: - Small / accessory provider (1 slot)

struct SwitchSmallProvider: AppIntentTimelineProvider {
    typealias Intent = SwitchSmallConfigurationAppIntent

    func placeholder(in context: Context) -> SwitchEntry {
        SwitchEntry(date: Date(), home: nil, slots: [sampleSlots[0]])
    }

    func snapshot(for configuration: Intent, in context: Context) async -> SwitchEntry {
        context.isPreview ? placeholder(in: context) : await createEntry(for: configuration)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<SwitchEntry> {
        let entry = await createEntry(for: configuration)
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func createEntry(for configuration: Intent) async -> SwitchEntry {
        let slot = await resolveSlot(entity: configuration.item1 as (any SwitchSlotResolvable)?)
        return SwitchEntry(date: Date(), home: configuration.home, slots: [slot])
    }
}

// MARK: - Medium provider (2 slots)

struct SwitchMediumProvider: AppIntentTimelineProvider {
    typealias Intent = SwitchMediumConfigurationAppIntent

    func placeholder(in context: Context) -> SwitchEntry {
        SwitchEntry(date: Date(), home: nil, slots: Array(sampleSlots.prefix(2)))
    }

    func snapshot(for configuration: Intent, in context: Context) async -> SwitchEntry {
        context.isPreview ? placeholder(in: context) : await createEntry(for: configuration)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<SwitchEntry> {
        let entry = await createEntry(for: configuration)
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func createEntry(for configuration: Intent) async -> SwitchEntry {
        async let s1 = resolveSlot(entity: configuration.item1 as (any SwitchSlotResolvable)?)
        async let s2 = resolveSlot(entity: configuration.item2 as (any SwitchSlotResolvable)?)
        return await SwitchEntry(date: Date(), home: configuration.home, slots: [s1, s2])
    }
}

// MARK: - Large provider (4 slots)

struct SwitchLargeProvider: AppIntentTimelineProvider {
    typealias Intent = SwitchLargeConfigurationAppIntent

    func placeholder(in context: Context) -> SwitchEntry {
        SwitchEntry(date: Date(), home: nil, slots: sampleSlots)
    }

    func snapshot(for configuration: Intent, in context: Context) async -> SwitchEntry {
        context.isPreview ? placeholder(in: context) : await createEntry(for: configuration)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<SwitchEntry> {
        let entry = await createEntry(for: configuration)
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func createEntry(for configuration: Intent) async -> SwitchEntry {
        async let s1 = resolveSlot(entity: configuration.item1 as (any SwitchSlotResolvable)?)
        async let s2 = resolveSlot(entity: configuration.item2 as (any SwitchSlotResolvable)?)
        async let s3 = resolveSlot(entity: configuration.item3 as (any SwitchSlotResolvable)?)
        async let s4 = resolveSlot(entity: configuration.item4 as (any SwitchSlotResolvable)?)
        return await SwitchEntry(date: Date(), home: configuration.home, slots: [s1, s2, s3, s4])
    }
}

// MARK: - Toggle Style

private struct PowerButtonToggleStyle: ToggleStyle {
    let diameter: CGFloat
    var showStateLabel = true

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 4) {
            Image(systemSymbol: .power)
                .font(diameter <= 44 ? .title3 : .title2)
                .foregroundStyle(configuration.isOn ? Color.white : Color.primary)
                .frame(width: diameter, height: diameter)
                .background(configuration.isOn ? Color.green : Color(uiColor: .systemFill))
                .clipShape(Circle())
            if showStateLabel {
                Text(configuration.isOn ? "ON" : "OFF")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(configuration.isOn ? Color.green : Color.secondary)
            }
        }
    }
}

// MARK: - Item Row (used in multi-item layouts)

private struct SwitchItemRow: View {
    let slot: SwitchEntry.Slot
    let home: Home?

    var body: some View {
        let item = slot.item
        let isOn = item.state == "ON"
        let label = item.label.isEmpty ? item.name : item.label
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .layoutPriority(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if let home {
                Toggle(isOn: isOn, intent: createToggleIntent(item: item, homeUUID: slot.homeUUID, home: home)) {}
                    .toggleStyle(PowerButtonToggleStyle(diameter: 36, showStateLabel: false))
            } else {
                // Static visual used in previews / widget gallery (no home configured yet)
                Image(systemSymbol: .power)
                    .font(.title3)
                    .foregroundStyle(isOn ? Color.white : Color.primary)
                    .frame(width: 36, height: 36)
                    .background(isOn ? Color.green : Color(uiColor: .systemFill))
                    .clipShape(Circle())
            }
        }
    }
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

// MARK: - Small Widget (1 item)

struct SwitchSmallWidgetView: View {
    let entry: SwitchEntry

    var body: some View {
        ZStack(alignment: .center) {
            OpenHABIconOverlay()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(10)

            if let slot = entry.slots.compactMap(\.self).first {
                let label = slot.item.label.isEmpty ? slot.item.name : slot.item.label
                VStack(spacing: 8) {
                    Text(label)
                        .font(.headline)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .padding(.top, 20)
                    Spacer()
                    if let home = entry.home {
                        Toggle(
                            isOn: slot.item.state == "ON",
                            intent: createToggleIntent(item: slot.item, homeUUID: slot.homeUUID, home: home)
                        ) {}
                            .toggleStyle(PowerButtonToggleStyle(diameter: 44))
                    } else {
                        let isOn = slot.item.state == "ON"
                        Image(systemSymbol: .power)
                            .font(.title2)
                            .foregroundStyle(isOn ? Color.white : Color.primary)
                            .frame(width: 44, height: 44)
                            .background(isOn ? Color.green : Color(uiColor: .systemFill))
                            .clipShape(Circle())
                    }
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

struct SwitchMediumWidgetView: View {
    let entry: SwitchEntry

    var body: some View {
        ZStack(alignment: .topLeading) {
            OpenHABIconOverlay()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(10)

            let filledSlots = Array(entry.slots.compactMap(\.self))
            if filledSlots.isEmpty {
                UnconfiguredPlaceholder()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filledSlots.indices, id: \.self) { index in
                        SwitchItemRow(slot: filledSlots[index], home: entry.home)
                            .padding(.horizontal)
                            .padding(.vertical, 10)
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

struct SwitchLargeWidgetView: View {
    let entry: SwitchEntry

    var body: some View {
        ZStack(alignment: .topLeading) {
            OpenHABIconOverlay()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(14)

            let filledSlots = Array(entry.slots.compactMap(\.self))
            if filledSlots.isEmpty {
                VStack(alignment: .center, spacing: 16) {
                    Image(systemSymbol: .gear)
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Configure Widget")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Long press the widget to configure which switches to control")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filledSlots.indices, id: \.self) { index in
                        SwitchItemRow(slot: filledSlots[index], home: entry.home)
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

struct SwitchAccessoryCircularView: View {
    let entry: SwitchEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let slot = entry.slots.compactMap(\.self).first {
                if let home = entry.home {
                    Button(intent: createToggleIntent(item: slot.item, homeUUID: slot.homeUUID, home: home)) {
                        VStack(spacing: 2) {
                            Image(systemSymbol: .switch2)
                                .font(.caption)
                            Text(slot.item.state ?? "?")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(spacing: 2) {
                        Image(systemSymbol: .switch2)
                            .font(.caption)
                        Text(slot.item.state ?? "?")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
            } else {
                Image(systemSymbol: .gear)
                    .font(.title3)
            }
        }
    }
}

struct SwitchAccessoryRectangularView: View {
    let entry: SwitchEntry

    var body: some View {
        if let slot = entry.slots.compactMap(\.self).first {
            let label = slot.item.label.isEmpty ? slot.item.name : slot.item.label
            if let home = entry.home {
                Button(intent: createToggleIntent(item: slot.item, homeUUID: slot.homeUUID, home: home)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let stateText = slot.item.state {
                            Text(stateText)
                                .font(.body)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        } else {
                            Text("No State")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let stateText = slot.item.state {
                        Text(stateText)
                            .font(.body)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    } else {
                        Text("No State")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } else {
            Text("Configure")
                .font(.caption)
        }
    }
}

struct SwitchAccessoryInlineView: View {
    let entry: SwitchEntry

    var body: some View {
        if let slot = entry.slots.compactMap(\.self).first {
            let label = slot.item.label.isEmpty ? slot.item.name : slot.item.label
            if let home = entry.home {
                Button(intent: createToggleIntent(item: slot.item, homeUUID: slot.homeUUID, home: home)) {
                    if let stateText = slot.item.state {
                        Text("\(label): \(stateText)")
                    } else {
                        Text(label)
                    }
                }
                .buttonStyle(.plain)
            } else {
                if let stateText = slot.item.state {
                    Text("\(label): \(stateText)")
                } else {
                    Text(label)
                }
            }
        } else {
            Text("Configure Widget")
        }
    }
}

// MARK: - Unified Entry View (dispatches by family)

struct SwitchWidgetEntryView: View {
    var entry: SwitchEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SwitchSmallWidgetView(entry: entry)
        case .systemMedium:
            SwitchMediumWidgetView(entry: entry)
        case .systemLarge:
            SwitchLargeWidgetView(entry: entry)
        case .accessoryCircular:
            SwitchAccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            SwitchAccessoryRectangularView(entry: entry)
        case .accessoryInline:
            SwitchAccessoryInlineView(entry: entry)
        default:
            SwitchSmallWidgetView(entry: entry)
        }
    }
}

extension SwitchWidgetItemEntity: SwitchSlotResolvable {}
extension SwitchMediumWidgetItemEntity: SwitchSlotResolvable {}
extension SwitchLargeWidgetItemEntity: SwitchSlotResolvable {}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    SwitchSmallWidget()
} timeline: {
    SwitchEntry(date: .now, home: nil, slots: [sampleSlots[0]])
}

#Preview("Medium", as: .systemMedium) {
    SwitchMediumWidget()
} timeline: {
    SwitchEntry(date: .now, home: nil, slots: Array(sampleSlots.prefix(2)))
}

#Preview("Large", as: .systemLarge) {
    SwitchLargeWidget()
} timeline: {
    SwitchEntry(date: .now, home: nil, slots: sampleSlots)
}

#Preview("Accessory Circular", as: .accessoryCircular) {
    SwitchSmallWidget()
} timeline: {
    SwitchEntry(date: .now, home: nil, slots: [sampleSlots[0]])
}

#Preview("Accessory Rectangular", as: .accessoryRectangular) {
    SwitchSmallWidget()
} timeline: {
    SwitchEntry(date: .now, home: nil, slots: [sampleSlots[0]])
}

#Preview("Accessory Inline", as: .accessoryInline) {
    SwitchSmallWidget()
} timeline: {
    SwitchEntry(date: .now, home: nil, slots: [sampleSlots[0]])
}
