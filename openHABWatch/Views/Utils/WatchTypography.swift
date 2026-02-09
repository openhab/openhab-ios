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

enum WatchTypography {
    static let labelFont: Font = .caption
    static let labelLineLimit = 2
    static let labelMinScale: CGFloat = 0.85

    static let detailFont: Font = .footnote
    static let detailLineLimit = 1
    static let detailMinScale: CGFloat = 0.85

    static let sectionFont: Font = .callout
    static let sectionLineLimit = 1
    static let sectionMinScale: CGFloat = 0.85

    static let controlFont: Font = .caption
    static let controlLineLimit = 1
    static let controlMinScale: CGFloat = 0.8

    static let secondaryFont: Font = .caption2
    static let secondaryLineLimit = 1
    static let secondaryMinScale: CGFloat = 0.8

    static let emphasisFont: Font = .headline
}

struct WatchLabelText: View {
    @ObservedObject var widget: OpenHABWidget

    var body: some View {
        TextLabelView(widget: widget, font: WatchTypography.labelFont, lineLimit: WatchTypography.labelLineLimit)
            .minimumScaleFactor(WatchTypography.labelMinScale)
            .truncationMode(.tail)
    }

    init(widget: OpenHABWidget) {
        self.widget = widget
    }
}
