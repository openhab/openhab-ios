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
import SFSafeSymbols
import SwiftUI

private struct TextRowConfig {
    let input: TextRowInput
}

@MainActor
private func makeTextRowContent(_ config: TextRowConfig) -> TextRowContent {
    TextRowContent(input: config.input)
}

private struct TextRowContent: View {
    let input: TextRowInput

    var body: some View {
        let displayState = input.displayState
        RowViewWithIcon(input: input, spacing: 8) {
            let labelColor: Color = input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor)
            let valueColor: Color = input.valueColor.isEmpty ? .secondary : Color(fromString: input.valueColor)
            let labelShown = !displayState.labelText.isEmpty

            if labelShown, let value = displayState.labelValue {
                // Concatenate label and value into one Text so the value trails inline
                // when the label wraps, instead of starting a new line on its own.
                // foregroundColor (not foregroundStyle) is used because only Text-returning
                // modifiers can be applied before Text + Text concatenation on iOS 16.
                // swiftlint:disable:next deprecated
                (Text(displayState.labelText).foregroundColor(labelColor)
                    + Text("  ")
                    // swiftlint:disable:next deprecated
                    + Text(value).foregroundColor(valueColor))
                    .font(.body)
                    .multilineTextAlignment(.leading)
            } else if labelShown {
                Text(displayState.labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(labelColor)
            } else if let value = displayState.labelValue {
                Text(value)
                    .ohTextToken(.rowValue)
                    .foregroundStyle(valueColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .contextMenu {
            if let text = displayState.labelValue ?? (displayState.labelText.isEmpty ? nil : displayState.labelText), !text.isEmpty {
                Button {
                    UIPasteboard.general.string = text
                } label: {
                    Label("Copy", systemSymbol: .squareAndArrowUp)
                }
            }
        }
    }
}

struct TextRowView: View {
    let input: TextRowInput

    var body: some View {
        makeTextRowContent(TextRowConfig(input: input))
    }
}

#if DEBUG
#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[3]
    VStack {
        TextRowView(input: TextRowInput.from(widget: widget))
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
#endif
