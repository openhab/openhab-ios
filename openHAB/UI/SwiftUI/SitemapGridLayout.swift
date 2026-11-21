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

struct SitemapGridSection: Identifiable {
    let id: String
    let headerIndex: Int?
    let groups: [SitemapGridRowGroup]

    static func makeSections(from rowInputs: [SitemapRowInput]) -> [SitemapGridSection] {
        var sections: [SitemapGridSection] = []
        var currentHeaderIndex: Int?
        var currentRows: [Int] = []

        for (rowIndex, rowInput) in rowInputs.enumerated() {
            guard rowInput.isGridSectionHeader else {
                currentRows.append(rowIndex)
                continue
            }

            appendSection(
                headerIndex: currentHeaderIndex,
                rows: currentRows,
                rowInputs: rowInputs,
                to: &sections
            )
            currentHeaderIndex = rowIndex
            currentRows = []
        }

        appendSection(
            headerIndex: currentHeaderIndex,
            rows: currentRows,
            rowInputs: rowInputs,
            to: &sections
        )
        return sections
    }

    private static func appendSection(headerIndex: Int?,
                                      rows: [Int],
                                      rowInputs: [SitemapRowInput],
                                      to sections: inout [SitemapGridSection]) {
        guard headerIndex != nil || !rows.isEmpty else { return }
        let id = headerIndex.flatMap { rowInputs[safe: $0]?.id }
            ?? rows.first.flatMap { rowInputs[safe: $0]?.id }
            ?? "empty-\(sections.count)"
        sections.append(
            SitemapGridSection(
                id: id,
                headerIndex: headerIndex,
                groups: SitemapGridRowGroup.makeGroups(from: rows, rowInputs: rowInputs)
            )
        )
    }
}

struct SitemapGridRowGroup: Identifiable {
    enum Content {
        case regular([Int])
        case fullWidth(Int)
    }

    let id: String
    let content: Content

    static func makeGroups(from rows: [Int], rowInputs: [SitemapRowInput]) -> [SitemapGridRowGroup] {
        var groups: [SitemapGridRowGroup] = []
        var regularRows: [Int] = []

        for rowIndex in rows {
            guard let rowInput = rowInputs[safe: rowIndex],
                  SitemapPresentationPolicy.usesFullWidthCell(for: rowInput) else {
                regularRows.append(rowIndex)
                continue
            }

            appendRegularRows(regularRows, rowInputs: rowInputs, to: &groups)
            regularRows = []
            groups.append(
                SitemapGridRowGroup(
                    id: "full-width-\(rowInput.id)",
                    content: .fullWidth(rowIndex)
                )
            )
        }

        appendRegularRows(regularRows, rowInputs: rowInputs, to: &groups)
        return groups
    }

    private static func appendRegularRows(_ rows: [Int],
                                          rowInputs: [SitemapRowInput],
                                          to groups: inout [SitemapGridRowGroup]) {
        guard let firstRowIndex = rows.first,
              let firstRow = rowInputs[safe: firstRowIndex] else { return }
        groups.append(
            SitemapGridRowGroup(
                id: "regular-\(firstRow.id)",
                content: .regular(rows)
            )
        )
    }
}

struct SitemapRowLayoutIdentity: Equatable {
    enum Role {
        case sectionHeader
        case fullWidth
        case regular
    }

    let rowID: RowID
    let role: Role

    static func makeIdentities(from rowInputs: [SitemapRowInput]) -> [SitemapRowLayoutIdentity] {
        rowInputs.map { rowInput in
            SitemapRowLayoutIdentity(rowID: rowInput.rowID, role: role(for: rowInput))
        }
    }

    private static func role(for rowInput: SitemapRowInput) -> Role {
        if RowLayoutPolicy.backgroundKind(for: rowInput) == .frame {
            return .sectionHeader
        }

        if SitemapPresentationPolicy.usesFullWidthCell(for: rowInput) {
            return .fullWidth
        }

        return .regular
    }
}

final class SitemapGridLayoutCache {
    private var cachedVersion: Int?
    private var cachedLayout = SitemapGridLayout(sections: [])

    func layout(for rowInputs: [SitemapRowInput], version: Int) -> SitemapGridLayout {
        guard cachedVersion != version else { return cachedLayout }

        cachedLayout = SitemapGridLayout.makeLayout(from: rowInputs)
        cachedVersion = version
        return cachedLayout
    }
}

struct SitemapGridLayout {
    let sections: [SitemapGridSection]

    static func makeLayout(from rowInputs: [SitemapRowInput]) -> SitemapGridLayout {
        SitemapGridLayout(sections: SitemapGridSection.makeSections(from: rowInputs))
    }
}

extension SitemapRowInput {
    var isGridSectionHeader: Bool {
        RowLayoutPolicy.backgroundKind(for: self) == .frame
    }

    var showsGridNavigationAffordance: Bool {
        switch self {
        case .linked:
            true
        case let .media(_, input):
            input.linkedPageLink != nil
        case .frame,
             .text,
             .slider,
             .selection,
             .segmented,
             .setpoint,
             .rollershutter,
             .toggle,
             .input,
             .colorPicker,
             .colorTemperature,
             .buttonGrid,
             .generic:
            false
        }
    }

    var usesConsistentGridCellHeight: Bool {
        switch self {
        case let .media(_, input):
            switch input.renderingKind {
            case .chart, .video:
                false
            case .image,
                 .webview,
                 .mapview,
                 .segmentedSwitch,
                 .toggleSwitch,
                 .rollershutterSwitch,
                 .slider,
                 .dateInput,
                 .textInput,
                 .text,
                 .frame,
                 .setpoint,
                 .selection,
                 .colorPicker,
                 .colorTemperaturePicker,
                 .buttonGrid,
                 .generic:
                true
            }
        case .linked,
             .text,
             .slider,
             .selection,
             .segmented,
             .setpoint,
             .rollershutter,
             .toggle,
             .input,
             .colorPicker,
             .colorTemperature,
             .generic:
            true
        case .frame,
             .buttonGrid:
            false
        }
    }

    var usesFullWidthGridCell: Bool {
        switch self {
        case let .media(_, input):
            switch input.renderingKind {
            case .chart, .video, .image, .webview, .mapview:
                true
            case .segmentedSwitch,
                 .toggleSwitch,
                 .rollershutterSwitch,
                 .slider,
                 .dateInput,
                 .textInput,
                 .text,
                 .frame,
                 .setpoint,
                 .selection,
                 .colorPicker,
                 .colorTemperaturePicker,
                 .buttonGrid,
                 .generic:
                false
            }
        case .buttonGrid:
            true
        case .frame,
             .linked,
             .text,
             .slider,
             .selection,
             .segmented,
             .setpoint,
             .rollershutter,
             .toggle,
             .input,
             .colorPicker,
             .colorTemperature,
             .generic:
            false
        }
    }
}
