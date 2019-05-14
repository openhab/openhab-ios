//
//  ButtonTableRowController.swift
//  openhabwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 18.06.18.
//  Copyright © 2018 private. All rights reserved.
//

import WatchKit
import Foundation

class ButtonTableRowController : NSObject {
    
    var lightGray = UIColor(red:0.1, green:0.1, blue:0.1, alpha:1.0)
    var darkGray = UIColor(red:0.1, green:0.1, blue:0.1, alpha:1.0)
    
    @IBOutlet var buttonSwitch: WKInterfaceSwitch!
    
    var item : Item?
    var interfaceController : InterfaceController?
    
    public func setInterfaceController(interfaceController : InterfaceController) {
        self.interfaceController = interfaceController
    }
    
    public func setItem(item : Item) {
        self.item = item
        buttonSwitch.setTitle(item.label)
        buttonSwitch.setOn(item.state == "ON")
    }
    
    @IBAction func doSwitchButtonPressed(_ value: Bool) {
        //toggleButtonColor(button: buttonSwitch)
        if item?.state == "ON" {
            item?.state = "OFF"
        } else {
            item?.state = "ON"
        }
        switchOpenHabItem(itemName: item!.name)
    }
    
    private func toggleButtonColor(button : WKInterfaceButton) {
        button.setBackgroundColor(self.darkGray)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(250)) {
            button.setBackgroundColor(self.lightGray)
        }
    }
    
    private func switchOpenHabItem(itemName : String) {
        
        interfaceController!.displayActivityImage()
        OpenHabService.singleton.switchOpenHabItem(itemName: itemName, {(data, response, error) -> Void in
            
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
        })
    }
}
