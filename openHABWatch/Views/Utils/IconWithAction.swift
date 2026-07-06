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

internal import SFSafeSymbols
import SwiftUI

struct IconWithAction: View {
    var systemSymbol: SFSymbol
    var accessibilityLabel: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemSymbol: systemSymbol)
                .font(.system(size: 25))
                .colorMultiply(.blue)
                .saturation(0.8)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    IconWithAction(systemSymbol: .chevronUpCircleFill, accessibilityLabel: "Increase") {}
}
