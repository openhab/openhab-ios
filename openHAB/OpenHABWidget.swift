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

extension OpenHABWidget {
    struct CodingData: Decodable {
        let widgetId: String
        let label: String
        let type: String
        let icon: String
        let url: String?
        let period: Double?
        let minValue: Double?
        let maxValue: Double?
        let step: Double?
        let refresh: Double?
        let height: Double?
        let isLeaf: String?
        let iconColor: String?
        let labelcolor: String?
        let valuecolor: String?
        let service: String?
        let state: String?
        let text: String?
        let item: OpenHABItem.CodingData?
        let linkedPage: OpenHABLinkedPage?
        let mappings: [OpenHABWidgetMapping]
        let widgets: [OpenHABWidget.CodingData]
    }
}

extension OpenHABWidget.CodingData {
    var openHABWidget: OpenHABWidget {
        let mappedWidgets = self.widgets.map { $0.openHABWidget }
        return OpenHABWidget(widgetId: self.widgetId, label: self.label, icon: self.icon, type: self.type, url: self.url, period: self.period, minValue: self.minValue, maxValue: self.maxValue, step: self.step, refresh: self.refresh, height: self.height, isLeaf: self.isLeaf, iconColor: self.iconColor, labelColor: self.labelcolor, valueColor: self.valuecolor, service: self.service, state: self.state, text: self.text, item: self.item?.openHABItem, linkedPage: self.linkedPage, mappings: self.mappings, widgets: mappedWidgets)
    }
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
    var text = ""
    var item: OpenHABItem?
    var linkedPage: OpenHABLinkedPage?
    var mappings: [OpenHABWidgetMapping] = []
    var image: UIImage?
    var widgets: [OpenHABWidget] = []

    let propertyNames: Set = ["widgetId", "label", "type", "icon", "type", "url", "period", "minValue", "maxValue", "step", "refresh", "height", "isLeaf", "iconColor", "labelcolor", "valuecolor", "service", "state", "text" ]

    // This is an ugly initializer

    init(widgetId: String, label: String, icon: String, type: String, url: String?, period: Double?, minValue: Double?, maxValue: Double?, step: Double?, refresh: Double?, height: Double?, isLeaf: String?, iconColor: String?, labelColor: String?, valueColor: String?, service: String?, state: String?, text: String?, item: OpenHABItem?, linkedPage: OpenHABLinkedPage?, mappings: [OpenHABWidgetMapping], widgets: [OpenHABWidget] ) {

        func toString (_ with: Double?) -> String {
            guard let d = with else { return ""}
            return String(format: "%.1f", d)
        }
        self.widgetId = widgetId
        self.label = label
        self.type = type
        self.icon = icon
        self.url = url ?? ""
        self.period = toString(period)
        self.minValue = toString(minValue)
        self.maxValue = toString(maxValue)
        self.step = toString(maxValue)
        self.refresh = toString(refresh)
        self.height = toString(height)
        self.isLeaf = isLeaf ?? ""
        self.iconColor = iconColor ?? ""
        self.labelcolor = labelColor ?? ""
        self.valuecolor = valueColor ?? ""
        self.service = service ?? ""
        self.state = state ?? ""
        self.text = text ?? ""
        self.item = item
        self.linkedPage = linkedPage
        self.mappings = mappings
        self.widgets = widgets
    }

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

    init(dictionary: [String: Any]) {
        super.init()
        mappings = [OpenHABWidgetMapping]()
        for key in dictionary.keys {
            if key == "item" {
                item = OpenHABItem(dictionary: dictionary[key] as! [String: Any])
            } else if key == "mappings" {
                let widgetMappings = dictionary["mappings"] as? [[String: Any]?]
                for mappingDictionary in widgetMappings ?? [] {
                    let mapping = OpenHABWidgetMapping(dictionary: mappingDictionary!)
                    mappings.append(mapping)
                }
            } else if key == "linkedPage" {
                linkedPage = OpenHABLinkedPage(dictionary: dictionary[key] as! [String: Any])
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
        for mapping in mappings where mapping.command == command {
            return (mappings as NSArray).index(of: mapping)
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
