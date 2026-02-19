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

private struct GenericRowConfig {
    let input: GenericRowInput
    let widget: OpenHABWidget
}

@MainActor
private func makeGenericRowContent(_ config: GenericRowConfig) -> GenericRowContent {
    GenericRowContent(input: config.input, iconWidget: config.widget)
}

private struct GenericRowContent: View {
    let input: GenericRowInput
    let iconWidget: OpenHABWidget

    var body: some View {
        let displayState = input.displayState
        HStack {
            IconView(widget: iconWidget)
                .frame(width: 32, height: 32)

            Text(displayState.labelText)
                .ohTextToken(.rowLabel)
                .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))

            Spacer()

            if let value = displayState.labelValue {
                Text(value)
                    .ohTextToken(.rowValue)
                    .foregroundStyle(input.valueColor.isEmpty ? .secondary : Color(fromString: input.valueColor))
            }
        }
    }
}

struct GenericRowView: View {
    @ObservedObject var widget: OpenHABWidget

    var body: some View {
        makeGenericRowContent(
            GenericRowConfig(
                input: GenericRowInput.from(widget: widget),
                widget: widget
            )
        )
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[6]
    List([widget]) { widget in
        GenericRowView(widget: widget)
    }
    .environmentObject(SitemapPageViewModel())
}
