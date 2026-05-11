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

import SFSafeSymbols
import SwiftUI

struct AnimatedSecureTextField: View {
    @Binding var text: String
    @State var isSecure = true
    var titleKey: String
    var body: some View {
        HStack(spacing: 4) {
            Button {
                isSecure.toggle()
            } label: {
                Image(systemSymbol: isSecure ? .eyeSlash : .eyeFill)
                    .foregroundStyle(.gray)
            }
            Spacer()
            HStack {
                if isSecure {
                    SecureField(titleKey, text: $text)
                        .textContentType(.password)
                        .multilineTextAlignment(.trailing) // Ensures text aligns to the right
                        .disableAutocorrection(true)
                } else {
                    TextField(titleKey, text: $text)
                        .textContentType(.password)
                        .multilineTextAlignment(.trailing) // Ensures text aligns to the right
                        .disableAutocorrection(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing) // Push to the right
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.3), value: isSecure)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var password = "password12"
        @State var isSecure = true

        var body: some View {
            Form {
                AnimatedSecureTextField(text: $password, titleKey: "Enter Password")
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
