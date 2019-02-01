//  Converted to Swift 4 by Swiftify v4.2.20229 - https://objectivec2swift.com/
//
//  OpenHABWidget.swift
//  HelloRestKit
//
//  Created by Victor Belov on 08/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
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
    var mappings: [OpenHABWidgetMapping] = []
    var image: UIImage?

    let propertyNames: Set = ["widgetId", "label", "type", "icon", "type", "url", "period", "minValue", "maxValue", "step", "refresh", "height", "isLeaf", "iconColor", "labelcolor", "valuecolor", "service", "state", "text" ]

    init(xml xmlElement: GDataXMLElement?) {
        super.init()
        mappings = [OpenHABWidgetMapping]()
        for child in (xmlElement?.children())! {
            if let child = child as? GDataXMLElement {
                if !(child.name() == "widget") {
                    if child.name() == "item" {
                        item = OpenHABItem(xml: child)
                    } else if child.name() == "mapping" {
                        let mapping = OpenHABWidgetMapping(xml: child)
                        mappings.append(mapping)
                    } else if child.name() == "linkedPage" {
                        linkedPage = OpenHABLinkedPage(xml: child)
                    } else {
                        if let name = child.name() {
                            if propertyNames.contains(name) {
                                setValue(child.stringValue, forKey: child.name() ?? "")
                            }
                        }
                    }
                }
            }
        }
    }

    init(dictionary: [String : Any]) {
        super.init()
        mappings = [OpenHABWidgetMapping]()
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
                        setValue((dictionary[key] as? NSNumber)?.stringValue ?? "", forKey: key )
                    }
                }
            }
        }
    }

    // Text prior to "["
    func labelText() -> String? {
        let array = label.components(separatedBy: "[")
        return array[0].trimmingCharacters(in: .whitespaces)
    }

    // Text after "["
    func labelValue() -> String? {
        let array = label.components(separatedBy: "[")
        if array.count > 1 {
            var characterSet = CharacterSet.whitespaces
            characterSet.insert(charactersIn: "]")
            return array[1].trimmingCharacters(in: characterSet)
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
        for mapping in mappings {
            if mapping.command == command {
                return (mappings as NSArray).index(of: mapping)
            }
        }
        return NSNotFound
    }

    var coordinate: CLLocationCoordinate2D {
        return item?.stateAsLocation()?.coordinate ?? kCLLocationCoordinate2DInvalid
    }

    var title: String? {
        return labelText()
    }
}
