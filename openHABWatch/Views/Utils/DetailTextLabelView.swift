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

struct DetailTextLabelView: View {
    @ObservedObject var widget: OpenHABWidget

    var body: some View {
        if let label = widget.labelValue {
            Text(label)
                .font(.footnote)
                .lineLimit(1)
                .foregroundStyle(!widget.valuecolor.isEmpty ? Color(fromString: widget.valuecolor) : .secondary)
        }
    }
}

#Preview {
    let widget = UserData(preview: true).widgets[2]
    DetailTextLabelView(widget: widget)
}
