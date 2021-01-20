// Copyright (c) 2010-2021 Contributors to the openHAB project
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

struct TextLabelView: View {
    @ObservedObject var widget: ObservableOpenHABWidget

    var body: some View {
        Text(widget.labelText ?? "")
            .font(.caption)
            .lineLimit(2)
            .foregroundColor(!widget.labelcolor.isEmpty ? Color(fromString: widget.labelcolor) : .primary)
    }
}

struct TextLabelView_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[2]
        return TextLabelView(widget: widget)
    }
}
