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

private struct FrameRowConfig {
    let input: FrameRowInput
}

@MainActor
private func makeFrameRowContent(_ config: FrameRowConfig) -> FrameRowContent {
    FrameRowContent(input: config.input)
}

private struct FrameRowContent: View {
    let input: FrameRowInput

    var body: some View {
        let displayState = input.displayState
        HStack {
            Text(displayState.labelText.uppercased())
                .ohTextToken(.section)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

struct FrameRowInputView: View {
    let input: FrameRowInput

    var body: some View {
        makeFrameRowContent(
            FrameRowConfig(
                input: input
            )
        )
    }
}

#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[6]
    List([widget]) { widget in
        FrameRowInputView(input: FrameRowInput.from(widget: widget))
    }
    .environmentObject(SitemapPageViewModel())
}
