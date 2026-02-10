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

struct WatchLabelText: View {
    let text: String

    var body: some View {
        Text(text)
            .watchTextStyle(.label)
    }
}

enum WatchTextStyle {
    case label
    case detail
    case section
    case control
    case secondary
    case emphasis
}

private struct WatchTextModifier: ViewModifier {
    let style: WatchTextStyle

    func body(content: Content) -> some View {
        switch style {
        case .label:
            content
                .font(WatchTypography.labelFont)
                .lineLimit(WatchTypography.labelLineLimit)
                .minimumScaleFactor(WatchTypography.labelMinScale)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
        case .detail:
            content
                .font(WatchTypography.detailFont)
                .lineLimit(WatchTypography.detailLineLimit)
                .minimumScaleFactor(WatchTypography.detailMinScale)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
        case .section:
            content
                .font(WatchTypography.sectionFont)
                .lineLimit(WatchTypography.sectionLineLimit)
                .minimumScaleFactor(WatchTypography.sectionMinScale)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
        case .control:
            content
                .font(WatchTypography.controlFont)
                .lineLimit(WatchTypography.controlLineLimit)
                .minimumScaleFactor(WatchTypography.controlMinScale)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
        case .secondary:
            content
                .font(WatchTypography.secondaryFont)
                .lineLimit(WatchTypography.secondaryLineLimit)
                .minimumScaleFactor(WatchTypography.secondaryMinScale)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
        case .emphasis:
            content
                .font(WatchTypography.emphasisFont)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
        }
    }
}

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

extension View {
    func watchTextStyle(_ style: WatchTextStyle) -> some View {
        modifier(WatchTextModifier(style: style))
    }
}
