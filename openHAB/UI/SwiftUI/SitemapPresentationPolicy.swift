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

import SwiftUI

enum SitemapPresentationPolicy {
    static let minimumColumnWidth: CGFloat = 340
    static let maximumColumnCount = 3
    static let gridSpacing: CGFloat = 8
    static let gridHorizontalPadding: CGFloat = 16
    static let gridVerticalPadding: CGFloat = 8
    static let regularGridCellHeight: CGFloat = 72
    static let gridFrameSeparatorHeight: CGFloat = 0.5

    static var minimumGridWidth: CGFloat {
        widthNeeded(for: 2)
    }

    static func columnCount(for availableWidth: CGFloat, horizontalSizeClass: UserInterfaceSizeClass?) -> Int {
        guard horizontalSizeClass == .regular else {
            return 1
        }

        let availableContentWidth = availableWidth - (gridHorizontalPadding * 2)
        let widestPossibleCount = min(maximumColumnCount, Int(availableContentWidth / minimumColumnWidth))
        guard widestPossibleCount >= 2 else { return 1 }

        for count in stride(from: widestPossibleCount, through: 2, by: -1)
            where availableContentWidth >= contentWidthNeeded(for: count) {
            return count
        }

        return 1
    }

    static func columns(count: Int) -> [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: minimumColumnWidth), spacing: gridSpacing, alignment: .top),
            count: count
        )
    }

    static func cellHeight(for rowInput: SitemapRowInput) -> CGFloat? {
        rowInput.usesConsistentGridCellHeight ? regularGridCellHeight : nil
    }

    static func usesFullWidthCell(for rowInput: SitemapRowInput) -> Bool {
        rowInput.usesFullWidthGridCell
    }

    private static func widthNeeded(for columnCount: Int) -> CGFloat {
        contentWidthNeeded(for: columnCount) + (gridHorizontalPadding * 2)
    }

    private static func contentWidthNeeded(for columnCount: Int) -> CGFloat {
        (CGFloat(columnCount) * minimumColumnWidth) + (CGFloat(columnCount - 1) * gridSpacing)
    }
}
