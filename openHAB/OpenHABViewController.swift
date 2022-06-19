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

import DynamicButton
import SideMenu
import SwiftMessages
import UIKit

class OpenHABViewController: UIViewController {
    var hamburgerButton: DynamicButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        let hamburgerButtonItem: UIBarButtonItem
        if #available(iOS 13.0, *) {
            let imageConfig = UIImage.SymbolConfiguration(textStyle: .largeTitle)
            let buttonImage = UIImage(systemName: "line.horizontal.3", withConfiguration: imageConfig)
            let button = UIButton(type: .custom)
            button.setImage(buttonImage, for: .normal)
            button.addTarget(self, action: #selector(OpenHABWebViewController.rightDrawerButtonPress(_:)), for: .touchUpInside)
            hamburgerButtonItem = UIBarButtonItem(customView: button)
            hamburgerButtonItem.customView?.heightAnchor.constraint(equalToConstant: 30).isActive = true
        } else {
            hamburgerButton = DynamicButton(frame: CGRect(x: 0, y: 0, width: 31, height: 31))
            hamburgerButton.setStyle(.hamburger, animated: true)
            hamburgerButton.addTarget(self, action: #selector(OpenHABWebViewController.rightDrawerButtonPress(_:)), for: .touchUpInside)
            hamburgerButton.strokeColor = view.tintColor
            hamburgerButtonItem = UIBarButtonItem(customView: hamburgerButton)
        }
        navigationItem.setRightBarButton(hamburgerButtonItem, animated: true)
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    @objc
    func rightDrawerButtonPress(_ sender: Any?) {
        guard let menu = SideMenuManager.default.rightMenuNavigationController else { return }
        present(menu, animated: true)
    }

    func showPopupMessage(seconds: Double, title: String, message: String) {
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

    // To be overridden by sub classes

    func reloadView() {}

    func viewName() -> String {
        "default"
    }
}
