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

struct TextRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel

    var body: some View {
        let displayState = widget.displayState
        HStack {
            IconView(widget: widget)
                .frame(width: 32, height: 32)

            Text(displayState.labelText)
                .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
                .lineLimit(1)

            Spacer()

            if let value = displayState.labelValue {
                Text(value)
                    .font(.body)
                    .foregroundStyle(widget.valuecolor.isEmpty ? .secondary : Color(fromString: widget.valuecolor))
                    .lineLimit(1)
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

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[3]
    VStack {
        TextRowView(widget: widget)
        Spacer()
    }
    .environmentObject(SitemapPageViewModel())
}
