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

import SFSafeSymbols
import SwiftUI

struct ImageWithAction: View {
    var systemName: String
    var action: () -> Void
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 25))
            .colorMultiply(.blue)
            .saturation(0.8)
            .onTapGesture {
                action()
            }
    }
}

struct ImageWithAction_Previews: PreviewProvider {
    static var previews: some View {
        ImageWithAction(systemName: "chevron.up.circle.fill") {}
    }
}
