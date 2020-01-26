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
struct PreferencesRowUIView: View {
    var label: String
    var content: String
    var body: some View {
        HStack {
            Text("\(label)")
                .fontWeight(.bold)
            Text(content)
        }
    }
}

struct PreferencesRowUIView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesRowUIView(label: "Label", content: "v02.2002")
    }
}
