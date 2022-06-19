// Copyright (c) 2010-2022 Contributors to the openHAB project
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
import SwiftMessages

class OpenHABViewController: UIViewController {
    func reloadView() {}
    
    func viewName() -> String {
        "default"
    }
    
    func showPopupMessage(seconds: Double, title:String, message: String) {
        var config = SwiftMessages.Config()
        config.duration = .seconds(seconds: seconds)
        config.presentationStyle = .bottom
        SwiftMessages.show(config: config) {
            let view = MessageView.viewFromNib(layout: .cardView)
            // ... configure the view
            view.configureTheme(.error)
            view.configureContent(title: NSLocalizedString("error", comment: ""), body: message)
            view.button?.setTitle(NSLocalizedString(title, comment: ""), for: .normal)
            view.buttonTapHandler = { _ in SwiftMessages.hide() }
            return view
        }
    }
}
