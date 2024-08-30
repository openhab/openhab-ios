// Copyright (c) 2010-2024 Contributors to the openHAB project
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

struct FrameCellView: View {
    @ObservedObject var widget: OpenHABWidget
    let gray = Color(UIColor.darkGray)

    var body: some View {
        Text(widget.label.uppercased())
            .font(.system(.callout))
            .lineLimit(1)
            .foregroundColor(Color(.ohSecondaryLabel))
            .padding()
            .background(gray.edgesIgnoringSafeArea(.all))
            .listRowInsets(EdgeInsets()) // Equivalent to separatorInset
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let widget = OpenHABWidget()
    widget.label = "??"
    return FrameCellView(widget: widget)
}
