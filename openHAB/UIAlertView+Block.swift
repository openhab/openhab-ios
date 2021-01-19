// Copyright (c) 2010-2021 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import ObjectiveC
import UIKit

private var kNSCBAlertWrapper = 0

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
