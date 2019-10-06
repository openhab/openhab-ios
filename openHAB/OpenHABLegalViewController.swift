//
//  OpenHABLegalViewController.swift
//  openHAB
//
//  Created by Victor Belov on 25/05/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

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

        if #available(iOS 13.0, *) {
            legalTextView.backgroundColor = .systemBackground
            legalTextView.textColor = .label
        } else {
            legalTextView.backgroundColor = .white
            legalTextView.textColor = .black
        }
    }
}
