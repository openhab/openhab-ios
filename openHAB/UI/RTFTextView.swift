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
import UIKit

struct RTFTextView: UIViewRepresentable {
    let rtfFileName: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = UIColor.clear
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if let url = Bundle.main.url(forResource: rtfFileName, withExtension: "rtf") {
            do {
                let attributedString = try NSAttributedString(
                    url: url,

                    options: [.characterEncoding: String.Encoding.utf8.rawValue],
                    documentAttributes: nil
                )
                uiView.attributedText = attributedString
                uiView.backgroundColor = .systemBackground
                uiView.textColor = .label
            } catch {
                Logger.rtfTextView.error("Failed to load RTF file: \(error.localizedDescription)")
            }
        } else {
            Logger.rtfTextView.warning("RTF file not found")
        }
    }
}

#Preview {
    RTFTextView(rtfFileName: "")
}
