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

struct FrameRow: View {
    let title: String

    var body: some View {
        HStack {
            Text(title.uppercased())
                .watchTextStyle(.section)
            Spacer()
        }
    }
}

#Preview {
    let widget = PreviewWidgetFactory.frame(label: "Environment")
    PreviewNavigationContainer {
        FrameRow(title: widget.labelText)
    }
}
