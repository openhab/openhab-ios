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

private struct GenericRowContent: View {
    let input: GenericRowInput

    var body: some View {
        let displayState = input.displayState
        RowViewWithIcon(input: input) {
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
    let input: GenericRowInput
    var body: some View {
        GenericRowContent(input: input)
    }
}

#if DEBUG
#Preview {
    let widget = PreviewConstants.openHABSitemapPage!.widgets[6]
    List([widget]) { widget in
        GenericRowView(input: GenericRowInput.from(widget: widget))
    }
}
#endif
