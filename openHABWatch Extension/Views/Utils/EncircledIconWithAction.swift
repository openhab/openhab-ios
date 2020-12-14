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

struct EncircledIconWithAction: View {
    var systemName: String
    var action: () -> Void
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 25))
            .colorMultiply(.blue)
            .saturation(0.8)
//        Circle()
//            .fill(Color.blue)
//            .frame(width: 35, height: 35)
//            .overlay(
//                Image(systemName: systemName)
//                    .font(.system(size: 25))
//            )
            .onTapGesture {
                self.action()
            }
    }
}

struct EncircledIconWithAction_Previews: PreviewProvider {
    static var previews: some View {
        EncircledIconWithAction(systemName: "chevron.up.circle.fill") {}
    }
}
