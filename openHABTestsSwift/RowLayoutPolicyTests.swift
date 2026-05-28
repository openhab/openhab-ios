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

@testable import openHAB
import OpenHABCore
import SwiftUI
import Testing

struct RowLayoutPolicyTests {
    @Test
    func linkedFrameUsesFrameInsetsAndBackground() {
        let widget = makeLinkedWidget(widgetID: "frame-linked", type: .frame, label: "Frame")
        let input = mappedRowInput(widget)

        #expect(RowLayoutPolicy.rowInsets(for: input) == EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        #expect(RowLayoutPolicy.backgroundKind(for: input) == .frame)
    }

    @Test
    func linkedFrameWithoutLabelUsesCompactFrameInsets() {
        let widget = makeLinkedWidget(widgetID: "frame-linked-empty", type: .frame, label: "")
        let input = mappedRowInput(widget)

        #expect(RowLayoutPolicy.rowInsets(for: input) == EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        #expect(RowLayoutPolicy.backgroundKind(for: input) == .frame)
    }

    @Test
    func linkedNonFrameUsesRegularInsetsAndBackground() {
        let widget = makeLinkedWidget(widgetID: "text-linked", type: .text, label: "Linked Text")
        let input = mappedRowInput(widget)

        #expect(RowLayoutPolicy.rowInsets(for: input) == RowLayoutPolicy.regularInsets)
        #expect(RowLayoutPolicy.backgroundKind(for: input) == .regular)
    }
}

private extension RowLayoutPolicyTests {
    func makeLinkedWidget(widgetID: String, type: OpenHABWidget.WidgetType, label: String) -> OpenHABWidget {
        OpenHABWidget(
            widgetId: widgetID,
            label: label,
            icon: "text",
            type: type,
            url: nil, period: nil, minValue: nil, maxValue: nil, step: nil,
            refresh: nil, height: nil, isLeaf: nil, iconColor: nil,
            labelColor: nil, valueColor: nil, service: nil, state: nil,
            text: nil, legend: nil, inputHint: nil, encoding: nil,
            item: nil,
            linkedPage: OpenHABPage(
                pageId: "linked",
                title: "Linked",
                link: "https://example.invalid/linked",
                leaf: false,
                widgets: [],
                icon: ""
            ),
            mappings: [],
            widgets: [],
            visibility: true,
            switchSupport: nil,
            forceAsItem: nil,
            labelSource: .sitemapDefinition,
            releaseOnly: nil
        )
    }

    func mappedRowInput(_ widget: OpenHABWidget) -> SitemapRowInput {
        SitemapRowInputMapper.map(
            widget: widget,
            rowID: RowID(pageKey: "test", widgetId: widget.widgetId, occurrence: 1)
        )
    }
}
