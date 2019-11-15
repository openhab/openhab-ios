// Copyright (c) 2010-2019 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import UIKit

class OpenHABLegalViewController: UIViewController {
    @IBOutlet private var legalTextView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        let legalPath = Bundle.main.url(forResource: "legal", withExtension: "rtf")
        var legalAttributedString: NSAttributedString?
        if let legalPath = legalPath {
            legalAttributedString = try? NSAttributedString(url: legalPath,
                                                            options: [.characterEncoding: String.Encoding.utf8.rawValue],
                                                            documentAttributes: nil)
        }
        if let legalAttributedString = legalAttributedString {
            legalTextView.attributedText = legalAttributedString
        }

        legalTextView.backgroundColor = .ohSystemBackground
        legalTextView.textColor = .ohLabel
    }
}
