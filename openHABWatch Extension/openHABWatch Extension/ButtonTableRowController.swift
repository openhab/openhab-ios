// Copyright (c) 2010-2023 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Foundation
import WatchKit

class ButtonTableRowController: NSObject {
    var item: Item?
    var interfaceController: InterfaceController?

    @IBOutlet private var buttonSwitch: WKInterfaceSwitch!

    @IBAction private func doSwitchButtonPressed(_ value: Bool) {
        guard let item else { return }
        let command = value ? "ON" : "OFF"
        switchOpenHabItem(for: item, command: command)
    }

    public func setInterfaceController(interfaceController: InterfaceController) {
        self.interfaceController = interfaceController
    }

    public func setItem(item: Item) {
        self.item = item
        buttonSwitch.setTitle(item.label)
        buttonSwitch.setOn(item.state == "ON")
    }

    private func toggleButtonColor(button: WKInterfaceButton) {
        button.setBackgroundColor(UIColor.darkGray)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(250)) {
            button.setBackgroundColor(UIColor.lightGray)
        }
    }

    private func switchOpenHabItem(for item: Item, command: String) {
        interfaceController!.displayActivityImage()
        OpenHabService.singleton.switchOpenHabItem(for: item, command: command) { (data, response, error) in

            self.interfaceController!.hideActivityImage()
            guard let data, error == nil else { // check for fundamental networking error
                self.interfaceController!.displayAlert(message: "error=\(String(describing: error))")
                return
            }

            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 { // check for http errors
                let message = "statusCode should be 200, but is \(httpStatus.statusCode)\n" +
                    "response = \(String(describing: response))"
                self.interfaceController!.displayAlert(message: message)
            }

            let responseString = String(data: data, encoding: .utf8)
            print("responseString = \(String(describing: responseString))")
        }
    }
}
