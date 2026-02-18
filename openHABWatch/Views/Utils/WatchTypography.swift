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
            content.ohTextToken(.rowLabel)
        case .detail:
            content.ohTextToken(.rowValue)
        case .section:
            content.ohTextToken(.section)
        case .control:
            content.ohTextToken(.control)
        case .secondary:
            content.ohTextToken(.secondary)
        case .emphasis:
            content.ohTextToken(.emphasis)
        }
    }
}

extension View {
    func watchTextStyle(_ style: WatchTextStyle) -> some View {
        modifier(WatchTextModifier(style: style))
    }
}
