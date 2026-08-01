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

import CommonUI
import OpenHABCore
import SwiftUI

enum RowBackgroundKind: Equatable {
    case frame
    case regular
}

enum RowLayoutPolicy {
    static let regularInsets = EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)

    static let frameBackground = Color(UIColor.ohSystemGroupedBackground)
    static let regularBackground = Color(UIColor.ohSecondarySystemGroupedBackground)

    static func rowInsets(for rowInput: SitemapRowInput) -> EdgeInsets {
        switch rowInput {
        case let .frame(_, input):
            return frameInsets(hasLabel: !input.displayState.labelText.isEmpty)
        case let .linked(_, input):
            if input.isFrame {
                return frameInsets(hasLabel: !input.displayState.labelText.isEmpty)
            }
            return regularInsets
        case .media:
            return regularInsets
        case .text,
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
            return regularInsets
        }
    }

    static func rowBackground(for rowInput: SitemapRowInput) -> Color {
        backgroundKind(for: rowInput) == .frame ? frameBackground : regularBackground
    }

    static func backgroundKind(for rowInput: SitemapRowInput) -> RowBackgroundKind {
        switch rowInput {
        case .frame:
            .frame
        case let .linked(_, input):
            input.isFrame ? .frame : .regular
        case .text,
             .slider,
             .selection,
             .segmented,
             .setpoint,
             .rollershutter,
             .toggle,
             .input,
             .colorPicker,
             .media,
             .colorTemperature,
             .buttonGrid,
             .generic:
            .regular
        }
    }

    private static func frameInsets(hasLabel: Bool) -> EdgeInsets {
        hasLabel
            ? EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
            : EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
    }
}

private struct LinkedPageRowInputView: View {
    let input: LinkedPageRowInput

    var body: some View {
        NavigationLink(value: LinkedPageNavigation(pageLink: input.linkedPageLink, pageTitle: input.linkedPageTitle)) {
            LinkedPageRowContent(input: input)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .background(Color.clear)
        }
        .buttonStyle(.plain)
    }
}

private struct LinkedPageRowContent: View {
    let input: LinkedPageRowInput

    var body: some View {
        let displayState = input.displayState
        HStack {
            IconInputView(input: input.icon, rowIdentity: input.widgetId, size: CGSize(width: 32, height: 32))

            Text(displayState.labelText)
                .ohTextToken(.rowLabel)
                .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))

            Spacer()

            if let value = displayState.labelValue {
                Text(value)
                    .ohTextToken(.rowValue)
                    .foregroundStyle(input.valueColor.isEmpty ? .secondary : Color(fromString: input.valueColor))
            }
        }
    }
}

/// Transitional adapter: drives list from immutable row inputs while reusing existing widget-driven rows.
struct EmbeddingRowInputView: View, Equatable {
    let rowInput: SitemapRowInput

    /// Subscribes to the view model so SwiftUI re-evaluates this view when
    /// rowInputs change — without this, rows that scroll into view after a
    /// foreground refresh may render stale data from a cached render.
    @EnvironmentObject private var viewModel: SitemapPageViewModel

    var body: some View {
        switch rowInput {
        case let .frame(_, input):
            FrameRowView(input: input)
                .contentShape(Rectangle())
        case let .linked(_, input):
            LinkedPageRowInputView(input: input)
                .contentShape(Rectangle())
        case let .slider(_, input):
            SliderRowView(input: input)
                .contentShape(Rectangle())
        case let .selection(_, input):
            SelectionRowView(input: input)
                .contentShape(Rectangle())
        case let .segmented(_, input):
            SegmentedRowView(input: input)
                .contentShape(Rectangle())
        case let .setpoint(_, input):
            SetpointRowView(input: input)
                .contentShape(Rectangle())
        case let .text(_, input):
            TextRowView(input: input)
                .contentShape(Rectangle())
        case let .toggle(_, input):
            SwitchRowView(input: input)
                .contentShape(Rectangle())
        case let .rollershutter(_, input):
            RollershutterRowView(input: input)
                .contentShape(Rectangle())
        case let .input(_, input):
            InputRowView(input: input)
                .contentShape(Rectangle())
        case let .colorPicker(_, input):
            ColorPickerRowView(input: input)
                .contentShape(Rectangle())
        case let .media(_, input):
            MediaRowView(input: input)
                .contentShape(Rectangle())
        case let .colorTemperature(_, input):
            ColorTemperaturePickerRowView(input: input)
                .contentShape(Rectangle())
        case let .buttonGrid(_, input):
            ButtonGridRowView(input: input)
                .contentShape(Rectangle())
        case let .generic(_, input):
            GenericRowView(input: input)
                .contentShape(Rectangle())
        }
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.rowInput == rhs.rowInput
    }
}
