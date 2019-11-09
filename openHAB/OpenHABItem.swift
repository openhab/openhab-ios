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

import CoreLocation
#if !os(watchOS)
import Fuzi
#endif
import os.log
import UIKit

final class OpenHABItem: NSObject, CommItem {
    var type = ""
    var groupType = ""
    var name = ""
    var state = ""
    var link = ""
    var label = ""
    var stateDescription: OpenHABStateDescription?

    init(name: String, type: String, state: String, link: String, label: String?, groupType: String?, stateDescription: OpenHABStateDescription?) {
        self.name = name
        self.type = type
        self.state = state
        self.link = link
        self.label = label ?? ""
        self.groupType = groupType ?? ""
        self.stateDescription = stateDescription
    }

    #if !os(watchOS)
    init(xml xmlElement: XMLElement) {
        super.init()
        for child in xmlElement.children {
            switch child.tag {
            case "name": name = child.stringValue
            case "type": type = child.stringValue
            case "groupType": groupType = child.stringValue
            case "state": state = child.stringValue
            case "link": link = child.stringValue
            default:
                break
            }
        }
    }
    #endif
}

extension OpenHABItem {

    func stateAsDouble() -> Double {
        return state.numberValue?.doubleValue ?? 0
    }

    func stateAsInt() -> Int {
        return state.numberValue?.intValue ?? 0
    }

    func stateAsUIColor() -> UIColor? {
        if state == "Uninitialized" {
            return UIColor(hue: 0, saturation: 0, brightness: 0, alpha: 1.0)
        } else {
            let values = state.components(separatedBy: ",")
            if values.count == 3 {
                let hue = CGFloat(state: values[0], divisor: 360)
                let saturation = CGFloat(state: values[1], divisor: 100)
                let brightness = CGFloat(state: values[2], divisor: 100)
                os_log("hue saturation brightness: %g %g %g", log: .default, type: .info, hue, saturation, brightness)
                return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
            } else {
                return UIColor(hue: 0, saturation: 0, brightness: 0, alpha: 1.0)
            }
        }
    }

    func stateAsLocation() -> CLLocation? {
        if type == "Location" {
            // Example of `state` string for location: '0.000000,0.000000,0.0' ('<latitude>,<longitued>,<altitude>')
            let locationComponents = state.components(separatedBy: ",")
            if locationComponents.count >= 2 {
                let latitude = CLLocationDegrees(Double(locationComponents[0]) ?? 0.0)
                let longitude = CLLocationDegrees(Double(locationComponents[1]) ?? 0.0)

                return CLLocation(latitude: latitude, longitude: longitude)
            }
        }
        return nil
    }
}

extension OpenHABItem {
    struct CodingData: Decodable {
        let type: String
        let groupType: String?
        let name: String
        let link: String
        let state: String
        let label: String?
        let stateDescription: OpenHABStateDescription.CodingData?
    }
}

extension OpenHABItem.CodingData {
    var openHABItem: OpenHABItem {
        return OpenHABItem(name: name, type: type, state: state, link: link, label: label, groupType: groupType, stateDescription: stateDescription?.openHABStateDescription)
    }
}

extension CGFloat {
    init(state string: String, divisor: Float) {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale(identifier: "EN")
        if let number = numberFormatter.number(from: string) {
            self.init(number.floatValue / divisor)
        } else {
            self.init(0)
        }
    }
}
