//
//  ButtonTableRowController.swift
//  openhabwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 18.06.18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation
import WatchKit

class ButtonTableRowController: NSObject {

    var item: Item?
    var interfaceController: InterfaceController?

    @IBOutlet var buttonSwitch: WKInterfaceSwitch!

    @IBAction func doSwitchButtonPressed(_ value: Bool) {
        guard let item = item else { return }
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
        OpenHabService.singleton.switchOpenHabItem(for: item, command: command) {(data, response, error) -> Void in

            self.interfaceController!.hideActivityImage()
            guard let data = data, error == nil else {                                                 // check for fundamental networking error
                self.interfaceController!.displayAlert(message: "error=\(String(describing: error))")
                return
            }

            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {           // check for http errors
                let message = "statusCode should be 200, but is \(httpStatus.statusCode)\n" +
                "response = \(String(describing: response))"
                self.interfaceController!.displayAlert(message: message)
            }

            let responseString = String(data: data, encoding: .utf8)
            print("responseString = \(String(describing: responseString))")
        }
    }
}
