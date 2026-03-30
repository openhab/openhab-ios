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

import OpenHABCore
import SwiftUI

public struct TextLabelView: View {
    @ObservedObject var widget: OpenHABWidget
    var font: Font?
    var token: OHTextToken
    var lineLimit: Int

    public var body: some View {
        Text(widget.labelText ?? "")
            .ohTextToken(token)
            .font(font)
            .lineLimit(lineLimit)
            .foregroundStyle(!widget.labelcolor.isEmpty ? Color(fromString: widget.labelcolor) : .primary)
    }

    public init(widget: OpenHABWidget,
                font: Font? = nil,
                token: OHTextToken = .rowLabel,
                lineLimit: Int = 1) {
        self.widget = widget
        self.font = font
        self.token = token
        self.lineLimit = lineLimit
    }
}
