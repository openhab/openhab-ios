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

import CoreGraphics
@testable import openHAB
import Testing

struct ScreenSaverLayoutCalculatorTests {
    @Test
    func oversizedTimeTextScalesDownToFitHorizontalMargins() {
        let containerSize = CGSize(width: 320, height: 568)
        let maxWidth = containerSize.width - ScreenSaverLayoutCalculator.edgeMargin * 2
        let configuration = ScreenSaverConfiguration(
            showsTime: true,
            showsDate: false,
            timeFontSizeRatio: 0.35
        )

        let layout = ScreenSaverLayoutCalculator.layout(
            containerSize: containerSize,
            configuration: configuration,
            dateText: nil,
            timeText: "11:11:11 PMMMMMMMMMMMMMMMMMMMMM",
            fontName: nil
        )

        #expect(layout.contentSize.width <= maxWidth)
        #expect(layout.timeFontSize < 112)
    }

    @Test
    func anchorAtTrailingEdgeKeepsContentInsideMargins() {
        let configuration = ScreenSaverConfiguration(
            showsTime: true,
            showsDate: true,
            timeFontSizeRatio: 0.2,
            dateFontRelativeSize: 0.4
        )

        let layout = ScreenSaverLayoutCalculator.layout(
            containerSize: CGSize(width: 390, height: 844),
            configuration: configuration,
            dateText: "Mar 10, 2026",
            timeText: "11:11 PM",
            fontName: nil
        )
        let position = layout.position(
            in: CGSize(width: 390, height: 844),
            anchor: CGPoint(x: 1, y: 1),
            edgeMargin: ScreenSaverLayoutCalculator.edgeMargin
        )

        #expect(position.x + layout.contentSize.width / 2 <= 370.5)
        #expect(position.y + layout.contentSize.height / 2 <= 824.5)
    }

    @Test
    func fittingIsStableWhenContentAlreadyFits() {
        let configuration = ScreenSaverConfiguration(
            showsTime: true,
            showsDate: true,
            timeFontSizeRatio: 0.2,
            dateFontRelativeSize: 0.4
        )

        let layout = ScreenSaverLayoutCalculator.layout(
            containerSize: CGSize(width: 1024, height: 768),
            configuration: configuration,
            dateText: "Mar 10, 2026",
            timeText: "11:11 PM",
            fontName: nil
        )

        #expect(abs(layout.timeFontSize - 153.6) < 0.001)
        #expect(abs(layout.dateFontSize - 61.44) < 0.001)
    }
}
