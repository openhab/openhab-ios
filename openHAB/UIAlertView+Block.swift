//
//  UIAlertView+Block.swift
//  openHAB
//
//  Created by Victor Belov on 16/07/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import ObjectiveC
import UIKit

private var kNSCBAlertWrapper = 0
extension UIAlertView {
    @objc
    func show(withCompletion completion: @escaping (_ alertView: UIAlertView?, _ buttonIndex: Int) -> Void) {
        let alertWrapper = NSCBAlertWrapper()
        alertWrapper.completionBlock = completion
        delegate = alertWrapper as AnyObject

        // Set the wrapper as an associated object
        objc_setAssociatedObject(self, &kNSCBAlertWrapper, alertWrapper, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // Show the alert as normal
        show()
    }

// MARK: - Class Public
}

class NSCBAlertWrapper: NSObject {
    var completionBlock: ((_ alertView: UIAlertView?, _ buttonIndex: Int) -> Void)?

// MARK: - UIAlertViewDelegate

    // Called when a button is clicked. The view will be automatically dismissed after this call returns
    func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
        if completionBlock != nil {
            completionBlock?(alertView, buttonIndex)
        }
    }

    // Called when we cancel a view (eg. the user clicks the Home button). This is not called when the user clicks the cancel button.
    // If not defined in the delegate, we simulate a click in the cancel button
    func alertViewCancel(_ alertView: UIAlertView) {
        // Just simulate a cancel button click
        if completionBlock != nil {
            completionBlock?(alertView, alertView.cancelButtonIndex)
        }
    }
}
