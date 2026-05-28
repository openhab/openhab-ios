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

import Foundation
import OpenHABCore

enum SitemapPageError: LocalizedError {
    case noActiveConnection
    case serviceUnavailable
    case noData

    var errorDescription: String? {
        switch self {
        case .noActiveConnection:
            "No active connection available."
        case .serviceUnavailable:
            "Service unavailable."
        case .noData:
            "No page data received."
        }
    }
}

enum CommandLifecycleSummary: Equatable {
    case idle
    case sending(count: Int)
    case failed(count: Int)
}

enum SitemapInteractionSummary: Equatable {
    case onlineIdle
    case connecting
    case offline
    case queued(count: Int)
    case sending(count: Int)
    case failed(count: Int)
}

enum RowInteractionState: Equatable {
    case idle
    case offline
    case queued
    case sending
    case failed
}

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
    let releaseOnly: Bool?
    let minValue: Double
    let maxValue: Double
    let step: Double
    let pattern: String?
    let unit: String?
    let type: OpenHABWidget.WidgetType
    let inputHintRawValue: String
    let encoding: String
    let labelSourceRawValue: String
    let yAxisDecimalPattern: String?
    let row: Int?
    let column: Int?
    let releaseCommand: String?
    let command: String?
    let stateless: Bool?
    let linkedPageLink: String?
    let linkedPageTitle: String?
    let mappings: [WidgetMappingKey]
    let item: WidgetItemKey?
    let childWidgets: [WidgetRenderKey]

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
            releaseOnly: widget.releaseOnly,
            minValue: widget.minValue,
            maxValue: widget.maxValue,
            step: widget.step,
            pattern: widget.pattern,
            unit: widget.unit,
            type: widget.type,
            inputHintRawValue: widget.inputHint.rawValue,
            encoding: widget.encoding,
            labelSourceRawValue: widget.labelSource.rawValue,
            yAxisDecimalPattern: widget.yAxisDecimalPattern,
            row: widget.row,
            column: widget.column,
            releaseCommand: widget.releaseCommand,
            command: widget.command,
            stateless: widget.stateless,
            linkedPageLink: widget.linkedPage?.link,
            linkedPageTitle: widget.linkedPage?.title,
            mappings: widget.mappings.map(WidgetMappingKey.init),
            item: WidgetItemKey.from(item: widget.item),
            childWidgets: widget.widgets.map(WidgetRenderKey.from)
        )
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

extension WidgetRenderKey {
    static func from(snapshot: WidgetMappingSnapshot) -> WidgetRenderKey {
        WidgetRenderKey(
            label: snapshot.label,
            icon: snapshot.icon,
            state: snapshot.state,
            iconColor: snapshot.iconColor,
            labelColor: snapshot.labelColor,
            valueColor: snapshot.valueColor,
            url: snapshot.url,
            period: snapshot.period,
            service: snapshot.service,
            legend: snapshot.legend,
            refresh: snapshot.refresh,
            height: snapshot.height,
            forceAsItem: snapshot.forceAsItem,
            visibility: snapshot.visibility,
            staticIcon: snapshot.staticIcon,
            switchSupport: snapshot.switchSupport,
            releaseOnly: snapshot.releaseOnly,
            minValue: snapshot.minValue,
            maxValue: snapshot.maxValue,
            step: snapshot.step,
            pattern: snapshot.pattern,
            unit: snapshot.unit,
            type: snapshot.widgetType,
            inputHintRawValue: snapshot.inputHintRawValue,
            encoding: snapshot.encoding,
            labelSourceRawValue: snapshot.labelSourceRawValue,
            yAxisDecimalPattern: snapshot.yAxisDecimalPattern,
            row: snapshot.row,
            column: snapshot.column,
            releaseCommand: snapshot.releaseCommand,
            command: snapshot.command,
            stateless: snapshot.stateless,
            linkedPageLink: snapshot.linkedPage?.link,
            linkedPageTitle: snapshot.linkedPage?.title,
            mappings: snapshot.mappings.map(WidgetMappingKey.init),
            item: WidgetItemKey.from(item: snapshot.item),
            childWidgets: snapshot.widgets.map(WidgetRenderKey.from)
        )
    }
}
