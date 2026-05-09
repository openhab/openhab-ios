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
import Foundation
import UIKit

struct ScreenSaverTextLayout {
    let timeFontSize: CGFloat
    let dateFontSize: CGFloat
    let contentSize: CGSize

    func position(in containerSize: CGSize, anchor: CGPoint, edgeMargin: CGFloat) -> CGPoint {
        let availableWidth = max(containerSize.width - contentSize.width - edgeMargin * 2, 0)
        let availableHeight = max(containerSize.height - contentSize.height - edgeMargin * 2, 0)

        let clampedAnchorX = min(max(anchor.x, 0), 1)
        let clampedAnchorY = min(max(anchor.y, 0), 1)

        let x = edgeMargin + contentSize.width / 2 + availableWidth * clampedAnchorX
        let y = edgeMargin + contentSize.height / 2 + availableHeight * clampedAnchorY

        return CGPoint(
            x: min(max(x, contentSize.width / 2), max(containerSize.width - contentSize.width / 2, contentSize.width / 2)),
            y: min(max(y, contentSize.height / 2), max(containerSize.height - contentSize.height / 2, contentSize.height / 2))
        )
    }
}

enum ScreenSaverLayoutCalculator {
    static let edgeMargin: CGFloat = 20

    static func layout(containerSize: CGSize,
                       configuration: ScreenSaverConfiguration,
                       dateText: String?,
                       timeText: String?,
                       fontName: String?) -> ScreenSaverTextLayout {
        let shortSide = min(containerSize.width, containerSize.height)
        let baseTimeFontSize = max(shortSide * configuration.timeFontSizeRatio, 48)
        let baseDateFontSize = baseTimeFontSize * configuration.dateFontRelativeSize
        let maximumWidth = max(containerSize.width - edgeMargin * 2, 1)
        let fittedSizes = fittedFontSizes(
            maximumWidth: maximumWidth,
            baseTimeFontSize: baseTimeFontSize,
            baseDateFontSize: baseDateFontSize,
            dateText: dateText,
            timeText: timeText,
            fontName: fontName
        )
        let fittedFonts = fonts(
            timeFontSize: fittedSizes.time,
            dateFontSize: fittedSizes.date,
            fontName: fontName
        )

        return ScreenSaverTextLayout(
            timeFontSize: fittedSizes.time,
            dateFontSize: fittedSizes.date,
            contentSize: measuredSize(
                dateText: dateText,
                timeText: timeText,
                dateFont: fittedFonts.date,
                timeFont: fittedFonts.time
            )
        )
    }

    private static func fittedFontSizes(maximumWidth: CGFloat,
                                        baseTimeFontSize: CGFloat,
                                        baseDateFontSize: CGFloat,
                                        dateText: String?,
                                        timeText: String?,
                                        fontName: String?) -> (time: CGFloat, date: CGFloat) {
        var timeFontSize = baseTimeFontSize
        var dateFontSize = baseDateFontSize

        for _ in 0 ..< 3 {
            let currentFonts = fonts(
                timeFontSize: timeFontSize,
                dateFontSize: dateFontSize,
                fontName: fontName
            )
            let currentWidth = measuredWidth(
                dateText: dateText,
                timeText: timeText,
                dateFont: currentFonts.date,
                timeFont: currentFonts.time
            )

            guard currentWidth > maximumWidth else {
                break
            }

            let correction = maximumWidth / currentWidth
            timeFontSize *= correction
            dateFontSize *= correction
        }

        return (timeFontSize, dateFontSize)
    }

    private static func fonts(timeFontSize: CGFloat,
                              dateFontSize: CGFloat,
                              fontName: String?) -> (time: UIFont, date: UIFont) {
        if let fontName,
           let timeFont = UIFont(name: fontName, size: timeFontSize),
           let dateFont = UIFont(name: fontName, size: dateFontSize) {
            return (timeFont, dateFont)
        }

        return (
            UIFont.monospacedDigitSystemFont(ofSize: timeFontSize, weight: .thin),
            UIFont.systemFont(ofSize: dateFontSize, weight: .regular)
        )
    }

    private static func measuredWidth(dateText: String?,
                                      timeText: String?,
                                      dateFont: UIFont,
                                      timeFont: UIFont) -> CGFloat {
        max(
            lineWidth(dateText, font: dateFont),
            lineWidth(timeText, font: timeFont)
        )
    }

    private static func measuredSize(dateText: String?,
                                     timeText: String?,
                                     dateFont: UIFont,
                                     timeFont: UIFont) -> CGSize {
        let width = measuredWidth(
            dateText: dateText,
            timeText: timeText,
            dateFont: dateFont,
            timeFont: timeFont
        )
        let height =
            (dateText == nil ? 0 : ceil(dateFont.lineHeight)) +
            (timeText == nil ? 0 : ceil(timeFont.lineHeight))

        return CGSize(width: ceil(width), height: ceil(height))
    }

    private static func lineWidth(_ text: String?, font: UIFont) -> CGFloat {
        guard let text, !text.isEmpty else {
            return 0
        }

        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}
