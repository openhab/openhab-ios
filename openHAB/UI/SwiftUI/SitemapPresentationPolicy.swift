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
    static let twoColumnMinimumWidth: CGFloat = 314
    static let threeColumnMinimumWidth: CGFloat = 340
    static let maximumColumnCount = 3
    static let gridSpacing: CGFloat = 8
    static let gridHorizontalPadding: CGFloat = 16
    static let gridVerticalPadding: CGFloat = 8
    static let regularGridCellHeight: CGFloat = 72
    static let gridFrameSeparatorHeight: CGFloat = 0.5

    static func minimumColumnWidth(for columnCount: Int) -> CGFloat {
        columnCount >= 3 ? threeColumnMinimumWidth : twoColumnMinimumWidth
    }

    static func columnCount(for availableWidth: CGFloat, horizontalSizeClass: UserInterfaceSizeClass?) -> Int {
        guard horizontalSizeClass == .regular else {
            return 1
        }

        // Two columns are size-class driven; only three columns need a width threshold.
        let availableContentWidth = availableWidth - (gridHorizontalPadding * 2)
        if availableContentWidth >= contentWidthNeeded(for: maximumColumnCount) {
            return maximumColumnCount
        }

        return 2
    }

    static func columns(count: Int) -> [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: minimumColumnWidth(for: count)), spacing: gridSpacing, alignment: .top),
            count: count
        )
    }

    static func cellHeight(for rowInput: SitemapRowInput) -> CGFloat? {
        rowInput.usesConsistentGridCellHeight ? regularGridCellHeight : nil
    }

    static func usesFullWidthCell(for rowInput: SitemapRowInput) -> Bool {
        rowInput.usesFullWidthGridCell
    }

    private static func contentWidthNeeded(for columnCount: Int) -> CGFloat {
        (CGFloat(columnCount) * minimumColumnWidth(for: columnCount)) + (CGFloat(columnCount - 1) * gridSpacing)
    }
}
