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
import os.log

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
        let period: String?
        let minValue: Double?
        let maxValue: Double?
        let step: Double?
        let refresh: Int?
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

class OpenHABWidget: NSObject, MKAnnotation {
    weak var delegate: OpenHABWidgetDelegate?
    var widgetId = ""
    var label = ""
    var icon = ""
    var type = ""
    var url = ""
    var period = ""
    var minValue = 0.0
    var maxValue = 100.0
    var step = 1.0
    var refresh = 0
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

    // This is an ugly initializer

    init(widgetId: String, label: String, icon: String, type: String, url: String?, period: String?, minValue: Double?, maxValue: Double?, step: Double?, refresh: Int?, height: Double?, isLeaf: String?, iconColor: String?, labelColor: String?, valueColor: String?, service: String?, state: String?, text: String?, item: OpenHABItem?, linkedPage: OpenHABLinkedPage?, mappings: [OpenHABWidgetMapping], widgets: [OpenHABWidget] ) {

        func toString (_ with: Double?) -> String {
            guard let d = with else { return ""}
            return String(format: "%.1f", d)
        }
        self.widgetId = widgetId
        self.label = label
        self.type = type
        self.icon = icon
        self.url = url ?? ""
        self.period = period ?? ""
        self.minValue = minValue ?? 0.0
        self.maxValue = maxValue ?? 100.0
        self.step = step ?? 1.0
        // Consider a minimal refresh rate of 100 ms, but 0 is special and means 'no refresh'
        if let refreshVal = refresh, refreshVal > 0 {
            self.refresh = max(100, refreshVal)
        } else {
            self.refresh = 0
        }
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

        // Sanitize minValue, maxValue and step: min <= max, step >= 0
        self.maxValue = max(self.minValue, self.maxValue)
        self.step = abs(self.step)
    }

    init(xml xmlElement: GDataXMLElement?) {
        let propertyNames: Set = ["widgetId", "label", "type", "icon", "type", "url", "period", "minValue", "maxValue", "step", "refresh", "height", "isLeaf", "iconColor", "labelcolor", "valuecolor", "service", "state", "text" ]
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

    func sendCommand(_ command: Double) {
        sendCommand(String(command))
    }

    func sendCommand(_ command: String?) {
        if delegate != nil && item != nil {
            delegate?.sendCommand(item, commandToSend: command)
        }
        if item == nil {
            os_log("Item = nil", log: .default, type: .info)
        }
        if delegate == nil {
            os_log("Delegate = nil", log: .default, type: .info)
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
