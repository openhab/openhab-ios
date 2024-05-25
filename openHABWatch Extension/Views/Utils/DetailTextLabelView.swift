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

import SwiftUI

struct DetailTextLabelView: View {
    @ObservedObject var widget: ObservableOpenHABWidget

    var body: some View {
        Unwrap(widget.labelValue) {
            Text($0)
                .font(.footnote)
                .lineLimit(1)
                .foregroundColor(!widget.valuecolor.isEmpty ? Color(fromString: widget.valuecolor) : .secondary)
        }
    }
}

struct DetailTextLabelView_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[2]
        return DetailTextLabelView(widget: widget)
    }
}
