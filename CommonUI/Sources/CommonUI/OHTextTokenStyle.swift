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

public enum OHTextToken {
    case rowLabel
    case rowValue
    case rowValueCompact
    case rowValueCallout
    case section
    case control
    case secondary
    case emphasis
}

public enum OHAccessibilityToken {
    public static let minimumHitTarget: CGFloat = 44
}

private struct OHTextTokenModifier: ViewModifier {
    let token: OHTextToken

    func body(content: Content) -> some View {
        let style = OHTextTokenStyle.from(token)
        return content
            .font(style.font)
            .lineLimit(style.lineLimit)
            .minimumScaleFactor(style.minimumScaleFactor)
            .multilineTextAlignment(.leading)
            .truncationMode(style.truncationMode)
    }
}

private struct OHTextTokenStyle {
    let font: Font
    let lineLimit: Int?
    let minimumScaleFactor: CGFloat
    let truncationMode: Text.TruncationMode

    init(font: Font, lineLimit: Int?, minimumScaleFactor: CGFloat, truncationMode: Text.TruncationMode = .tail) {
        self.font = font
        self.lineLimit = lineLimit
        self.minimumScaleFactor = minimumScaleFactor
        self.truncationMode = truncationMode
    }

    static func from(_ token: OHTextToken) -> OHTextTokenStyle {
        #if os(watchOS)
        switch token {
        case .rowLabel:
            OHTextTokenStyle(font: .caption, lineLimit: 2, minimumScaleFactor: 0.85)
        case .rowValue:
            OHTextTokenStyle(font: .footnote, lineLimit: 1, minimumScaleFactor: 0.85)
        case .rowValueCompact:
            OHTextTokenStyle(font: .caption2, lineLimit: 1, minimumScaleFactor: 0.8)
        case .rowValueCallout:
            OHTextTokenStyle(font: .footnote, lineLimit: 1, minimumScaleFactor: 0.85)
        case .section:
            OHTextTokenStyle(font: .callout, lineLimit: 1, minimumScaleFactor: 0.85)
        case .control:
            OHTextTokenStyle(font: .caption, lineLimit: 1, minimumScaleFactor: 0.8)
        case .secondary:
            OHTextTokenStyle(font: .caption2, lineLimit: 1, minimumScaleFactor: 0.8)
        case .emphasis:
            OHTextTokenStyle(font: .headline, lineLimit: 1, minimumScaleFactor: 0.8)
        }
        #else
        switch token {
        case .rowLabel:
            OHTextTokenStyle(font: .body, lineLimit: nil, minimumScaleFactor: 1.0)
        case .rowValue:
            OHTextTokenStyle(font: .body, lineLimit: nil, minimumScaleFactor: 0.9)
        case .rowValueCompact:
            OHTextTokenStyle(font: .caption, lineLimit: 1, minimumScaleFactor: 0.9)
        case .rowValueCallout:
            OHTextTokenStyle(font: .callout, lineLimit: 1, minimumScaleFactor: 0.9)
        case .section:
            OHTextTokenStyle(font: .callout, lineLimit: 1, minimumScaleFactor: 0.85)
        case .control:
            OHTextTokenStyle(font: .footnote, lineLimit: 1, minimumScaleFactor: 0.85)
        case .secondary:
            OHTextTokenStyle(font: .caption, lineLimit: 1, minimumScaleFactor: 0.9)
        case .emphasis:
            OHTextTokenStyle(font: .headline, lineLimit: 1, minimumScaleFactor: 0.9)
        }
        #endif
    }
}

public extension View {
    func ohTextToken(_ token: OHTextToken) -> some View {
        modifier(OHTextTokenModifier(token: token))
    }

    /// Applies the standard minimum tappable target to compact interactive controls.
    ///
    /// Use this on small buttons, text pills, or custom gesture targets embedded in
    /// rows. Full-width controls and rows with their own hit area do not need it.
    func ohMinimumHitTarget(_ minHeight: CGFloat = OHAccessibilityToken.minimumHitTarget) -> some View {
        frame(minHeight: minHeight)
    }
}
