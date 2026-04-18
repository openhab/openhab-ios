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

import OpenHABCore

enum CommandSendOrigin: String {
    case command
    case update
}

enum PageUpdateOrigin: String {
    case initialPoll
    case longPolling
}

struct QueuedCommand {
    let command: String
    let version: Int
}

// swiftlint:disable:next file_types_order
struct WidgetRenderKey: Equatable {
    let label: String
    let icon: String
    let state: String
    let iconColor: String
    let labelColor: String
    let valueColor: String
    let url: String
    let period: String
    let service: String
    let legend: Bool?
    let refresh: Int
    let height: Double?
    let forceAsItem: Bool?
    let visibility: Bool
    let staticIcon: Bool?
    let switchSupport: Bool
    let minValue: Double
    let maxValue: Double
    let step: Double
    let pattern: String?
    let unit: String?
    let type: OpenHABWidget.WidgetType
    let linkedPageLink: String?
    let linkedPageTitle: String?
    let mappings: [WidgetMappingKey]
    let item: WidgetItemKey?
    let childWidgetIDs: [String]

    static func from(widget: OpenHABWidget) -> WidgetRenderKey {
        WidgetRenderKey(
            label: widget.label,
            icon: widget.icon,
            state: widget.state,
            iconColor: widget.iconColor,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            url: widget.url,
            period: widget.period,
            service: widget.service,
            legend: widget.legend,
            refresh: widget.refresh,
            height: widget.height,
            forceAsItem: widget.forceAsItem,
            visibility: widget.visibility,
            staticIcon: widget.staticIcon,
            switchSupport: widget.switchSupport,
            minValue: widget.minValue,
            maxValue: widget.maxValue,
            step: widget.step,
            pattern: widget.pattern,
            unit: widget.unit,
            type: widget.type,
            linkedPageLink: widget.linkedPage?.link,
            linkedPageTitle: widget.linkedPage?.title,
            mappings: widget.mappings.map(WidgetMappingKey.init),
            item: WidgetItemKey.from(item: widget.item),
            childWidgetIDs: widget.widgets.map(\.widgetId)
        )
    }

    // Could be synthesized automatically by compiler. But this takes too long
    static func == (lhs: WidgetRenderKey, rhs: WidgetRenderKey) -> Bool {
        lhs.label == rhs.label &&
            lhs.icon == rhs.icon &&
            lhs.state == rhs.state &&
            lhs.iconColor == rhs.iconColor &&
            lhs.labelColor == rhs.labelColor &&
            lhs.valueColor == rhs.valueColor &&
            lhs.url == rhs.url &&
            lhs.period == rhs.period &&
            lhs.service == rhs.service &&
            lhs.legend == rhs.legend &&
            lhs.refresh == rhs.refresh &&
            lhs.height == rhs.height &&
            lhs.forceAsItem == rhs.forceAsItem &&
            lhs.visibility == rhs.visibility &&
            lhs.staticIcon == rhs.staticIcon &&
            lhs.switchSupport == rhs.switchSupport &&
            lhs.minValue == rhs.minValue &&
            lhs.maxValue == rhs.maxValue &&
            lhs.step == rhs.step &&
            lhs.pattern == rhs.pattern &&
            lhs.unit == rhs.unit &&
            lhs.type == rhs.type &&
            lhs.linkedPageLink == rhs.linkedPageLink &&
            lhs.linkedPageTitle == rhs.linkedPageTitle &&
            lhs.mappings == rhs.mappings &&
            lhs.item == rhs.item &&
            lhs.childWidgetIDs == rhs.childWidgetIDs
    }
}

struct WidgetMappingKey: Equatable {
    let command: String
    let label: String
    let row: Int?
    let column: Int?
    let icon: String?
    let releaseCommand: String?

    init(_ mapping: OpenHABWidgetMapping) {
        command = mapping.command
        label = mapping.label
        row = mapping.row
        column = mapping.column
        icon = mapping.icon
        releaseCommand = mapping.releaseCommand
    }
}

struct WidgetItemKey: Equatable {
    let name: String
    let state: String?
    let link: String
    let label: String
    let type: OpenHABItem.ItemType?
    let groupType: OpenHABItem.ItemType?
    let stateDescription: WidgetStateDescriptionKey?
    let commandOptions: [WidgetCommandOptionKey]

    static func from(item: OpenHABItem?) -> WidgetItemKey? {
        guard let item else { return nil }
        return WidgetItemKey(
            name: item.name,
            state: item.state,
            link: item.link,
            label: item.label,
            type: item.type,
            groupType: item.groupType,
            stateDescription: WidgetStateDescriptionKey.from(stateDescription: item.stateDescription),
            commandOptions: item.commandDescription?.commandOptions.map(WidgetCommandOptionKey.init) ?? []
        )
    }
}

struct WidgetStateDescriptionKey: Equatable {
    let minimum: Double
    let maximum: Double
    let step: Double
    let readOnly: Bool
    let numberPattern: String?
    let options: [WidgetOptionKey]

    static func from(stateDescription: OpenHABStateDescription?) -> WidgetStateDescriptionKey? {
        guard let stateDescription else { return nil }
        return WidgetStateDescriptionKey(
            minimum: stateDescription.minimum,
            maximum: stateDescription.maximum,
            step: stateDescription.step,
            readOnly: stateDescription.readOnly,
            numberPattern: stateDescription.numberPattern,
            options: stateDescription.options.map(WidgetOptionKey.init)
        )
    }
}

struct WidgetOptionKey: Equatable {
    let value: String
    let label: String

    init(_ option: OpenHABOptions) {
        value = option.value
        label = option.label
    }
}

struct WidgetCommandOptionKey: Equatable {
    let command: String
    let label: String?

    init(_ option: OpenHABCommandOptions) {
        command = option.command
        label = option.label
    }
}
