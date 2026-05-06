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

import SFSafeSymbols
import SwiftUI

/// A reusable row layout that renders an `IconInputView` followed by
/// caller-provided content inside an `HStack`.
struct RowViewWithIcon<Content: View>: View {
    let input: any RowWithIconInput
    let fallbackSymbol: SFSymbol?
    let alignment: VerticalAlignment
    let spacing: CGFloat?
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: alignment, spacing: spacing) {
            if input.icon.showIcon {
                IconInputView(input: input.icon, rowIdentity: input.widgetId, size: CGSize(width: 32, height: 32), fallbackSymbol: fallbackSymbol)
            }
            content()
        }
    }

    init(input: any RowWithIconInput,
         fallbackSymbol: SFSymbol? = nil,
         alignment: VerticalAlignment = .center,
         spacing: CGFloat? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.input = input
        self.fallbackSymbol = fallbackSymbol
        self.alignment = alignment
        self.spacing = spacing
        self.content = content
    }
}
