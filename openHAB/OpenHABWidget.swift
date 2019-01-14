//  Converted to Swift 4 by Swiftify v4.2.20229 - https://objectivec2swift.com/
//
//  OpenHABWidget.swift
//  HelloRestKit
//
//  Created by Victor Belov on 08/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

import Foundation
import MapKit

protocol OpenHABWidgetDelegate: NSObjectProtocol {
    func sendCommand(_ item: OpenHABItem?, commandToSend command: String?)
}

@objcMembers class OpenHABWidget: NSObject, MKAnnotation {
    weak var delegate: OpenHABWidgetDelegate?
    var widgetId = ""
    var label = ""
    var icon = ""
    var type = ""
    var url = ""
    var period = ""
    var minValue = ""
    var maxValue = ""
    var step = ""
    var refresh = ""
    var height = ""
    var isLeaf = ""
    var iconColor = ""
    var labelcolor = ""
    var valuecolor = ""
    var service = ""
    var state = ""
    var item: OpenHABItem?
    var linkedPage: OpenHABLinkedPage?
    var text = ""
    var mappings: [AnyHashable] = []
    var image: UIImage?

    let propertyNames: Set = ["widgetId", "label", "type", "icon", "type", "url", "period", "minValue", "maxValue", "step", "refresh", "height", "isLeaf", "iconColor", "labelcolor", "valuecolor", "service", "state", "text" ]

    init(xml xmlElement: GDataXMLElement?) {
        super.init()
        mappings = [AnyHashable]()
//        for child: GDataXMLElement? in (xmlElement?.children())! {
//            if !(child?.name() == "widget") {
//                if child?.name() == "item" {
//                    item = OpenHABItem(xml: child)
//                } else if child?.name() == "mapping" {
//                    // MARK - HORROR - needs to be reverted
//                    let mapping = OpenHABWidgetMapping(xml: child) as? OpenHABWidgetMapping
//                    if let mapping = mapping {
//                        mappings.append(mapping)
//                    }
//                } else if child?.name() == "linkedPage" {
//                    linkedPage = OpenHABLinkedPage(xml: child)
//                } else {
//                    let propertyValue = child?.stringValue ?? ""
//                    if let name = child?.name() {
//                        if allPropertyNames().contains(name) {
//                            setValue(propertyValue, forKey: child?.name() ?? "")
//                        }
//                    }
//                }
//            }
//        }
    }

    init(dictionary: [String : Any]) {
        super.init()
        mappings = [AnyHashable]()
        for key in dictionary.keys {
            if key == "item" {
                item = OpenHABItem(dictionary: dictionary[key] as! [String:Any])
            } else if key == "mappings" {
                let widgetMappings = dictionary["mappings"] as? [[String:Any]?]
                for mappingDictionary in widgetMappings ?? [] {
                    let mapping = OpenHABWidgetMapping(dictionary: mappingDictionary!)
                    mappings.append(mapping)
                }
            } else if key == "linkedPage" {
                linkedPage = OpenHABLinkedPage(dictionary: dictionary[key] as! [String:Any])
            } else {
                if dictionary[key] is String {
                    if propertyNames.contains(key) {
                        setValue(dictionary[key], forKey: key)
                    }
                } else {
                    if propertyNames.contains(key) {
                        setValue((dictionary[key] as? NSNumber)?.stringValue ?? "", forKey: key ?? "")
                    }
                }
            }
        }
    }

    func labelText() -> String? {
        let array = label.components(separatedBy: "[")
        var valueString = array[0]
        while valueString.hasSuffix(" ") {
            valueString = (valueString as? NSString)?.substring(to: valueString.count - 1) ?? ""
        }
        return valueString
    }

    func labelValue() -> String? {
        let array = label.components(separatedBy: "[")
        if array.count > 1 {
            var valueString = array[1]
            while valueString.hasSuffix("]") || valueString.hasSuffix(" ") {
                valueString = (valueString as? NSString)?.substring(to: valueString.count - 1) ?? ""
            }
            return valueString
        }
        return nil
    }

    func sendCommand(_ command: String?) {
        if delegate != nil && item != nil {
            delegate?.sendCommand(item, commandToSend: command)
        }
        if item == nil {
            print("Item = nil")
        }
        if delegate == nil {
            print("Delegate = nil")
        }
    }

    func mappingIndex(byCommand command: String?) -> Int {
        for mapping: OpenHABWidgetMapping in mappings as? [OpenHABWidgetMapping] ?? [] {
            if (mapping.command == command) {
                return (mappings as NSArray).index(of: mapping)
            }
        }
        return NSNotFound
    }

    var coordinate: CLLocationCoordinate2D {
        return (item?.stateAsLocation()?.coordinate)!
    }

    var title: String? {
        return labelText()
    }
}
