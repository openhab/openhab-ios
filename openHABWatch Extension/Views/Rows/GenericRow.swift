// Copyright (c) 2010-2020 Contributors to the openHAB project
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

// swiftlint:disable file_types_order
struct GenericRow: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    var body: some View {
        HStack {
            IconView(widget: widget, settings: settings)
            TextLabelView(widget: widget)
            Spacer()
            DetailTextLabelView(widget: widget)
            if widget.linkedPage != nil {
x   
            }
        }
    }
}

struct GenericRow_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[7]
        return GenericRow(widget: widget)
    }
}
