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

private struct TextRowContent: View {
    let input: TextRowInput

    var body: some View {
        let displayState = input.displayState
        RowViewWithIcon(input: input, spacing: 8) {
            let labelShown = !displayState.labelText.isEmpty
            HStack {
                if labelShown {
                    Text(displayState.labelText)
                        .ohTextToken(.rowLabel)
                        .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))

                    Spacer(minLength: 8)
                }

                if let value = displayState.labelValue {
                    let text = Text(value)
                        .ohTextToken(.rowValue)
                        .foregroundStyle(input.valueColor.isEmpty ? .secondary : Color(fromString: input.valueColor))
                    if !labelShown {
                        text.frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        text
                    }
                }
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
        TextRowContent(input: input)
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
