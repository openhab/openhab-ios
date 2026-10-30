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
    static let threeColumnMinimumWidth: CGFloat = 340
    static let maximumColumnCount = 3
    static let gridSpacing: CGFloat = 8
    static let gridHorizontalPadding: CGFloat = 16
    static let gridVerticalPadding: CGFloat = 8
    static let regularGridCellHeight: CGFloat = 72
    static let gridFrameSeparatorHeight: CGFloat = 0.5

    static func columnCount(for availableWidth: CGFloat, horizontalSizeClass: UserInterfaceSizeClass?) -> Int {
        let availableContentWidth = availableWidth - (gridHorizontalPadding * 2)

        switch horizontalSizeClass {
        case .regular where availableContentWidth >= contentWidthNeeded(for: maximumColumnCount):
            return maximumColumnCount
        case .regular:
            return 2
        default:
            return 1
        }
    }

    static func columns(count: Int) -> [GridItem] {
        let gridItem = count == maximumColumnCount
            ? GridItem(.flexible(minimum: threeColumnMinimumWidth), spacing: gridSpacing, alignment: .top)
            : GridItem(.flexible(), spacing: gridSpacing, alignment: .top)
        return Array(repeating: gridItem, count: count)
    }

    static func cellHeight(for rowInput: SitemapRowInput) -> CGFloat? {
        rowInput.usesConsistentGridCellHeight ? regularGridCellHeight : nil
    }

    static func usesFullWidthCell(for rowInput: SitemapRowInput) -> Bool {
        rowInput.usesFullWidthGridCell
    }

    private static func contentWidthNeeded(for columnCount: Int) -> CGFloat {
        (CGFloat(columnCount) * threeColumnMinimumWidth) + (CGFloat(columnCount - 1) * gridSpacing)
    }
}
