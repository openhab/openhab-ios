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

import OpenHABCore
import os.log
import SwiftUI

struct RTFTextView: View {
    let rtfFileName: String
    @State private var content: AttributedString = AttributedString("")

    var body: some View {
        ScrollView {
            Text(content)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .task { await load() }
    }

    private func load() async {
        guard let url = Bundle.main.url(forResource: rtfFileName, withExtension: "rtf"),
              let ns = try? NSAttributedString(
                  url: url,
                  options: [.characterEncoding: String.Encoding.utf8.rawValue],
                  documentAttributes: nil
              ),
              let result = try? AttributedString(ns, including: \.foundation)
        else {
            Logger.rtfTextView.warning("RTF file '\(rtfFileName)' not found or could not be parsed")
            return
        }
        content = result
    }
}

#Preview {
    RTFTextView(rtfFileName: "")
}
