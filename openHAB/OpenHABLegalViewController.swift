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
    @IBOutlet var legalTextView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        let legalPath: URL? = Bundle.main.url(forResource: "legal", withExtension: "rtf")
        var legalAttributedString: NSAttributedString?
        if let legalPath = legalPath {
            legalAttributedString = try? NSAttributedString(fileURL: legalPath, options: [NSAttributedString.DocumentAttributeKey.documentType: NSAttributedString.DocumentType.rtf.rawValue], documentAttributes: nil)
        }
        if let legalAttributedString = legalAttributedString {
            legalTextView.attributedText = legalAttributedString
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
