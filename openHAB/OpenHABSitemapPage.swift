//  Converted to Swift 4 by Swiftify v4.2.20229 - https://objectivec2swift.com/
//
//  OpenHABSitemapPage.swift
//  HelloRestKit
//
//  Created by Victor Belov on 10/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import Foundation

protocol OpenHABSitemapPageDelegate: NSObjectProtocol {
    func sendCommand(_ item: OpenHABItem?, commandToSend command: String?)
}

extension OpenHABSitemapPage {

    struct CodingData: Decodable {
        let pageId: String
        let title: String
        let link: String
        let leaf: String
        let widgets: [OpenHABWidget.CodingData]

        private enum CodingKeys: String, CodingKey {
            case pageId = "id"
            case title
            case link
            case leaf
            case widgets
        }
    }
}

extension OpenHABSitemapPage.CodingData {
    var openHABSitemapPage: OpenHABSitemapPage {
        let mappedWidgets = self.widgets.map { $0.openHABWidget }
        return OpenHABSitemapPage(pageId: self.pageId, title: self.title, link: self.link, leaf: self.leaf, widgets: mappedWidgets)
    }
}

class OpenHABSitemapPage: NSObject, OpenHABWidgetDelegate {
    weak var delegate: OpenHABSitemapPageDelegate?
    var widgets: [OpenHABWidget] = []
    var pageId = ""
    var title = ""
    var link = ""
    var leaf = ""

    let propertyNames: Set = ["pageId", "title", "link", "leaf"]

    init(pageId: String, title: String, link: String, leaf: String, widgets: [OpenHABWidget]) {
        super.init()
        self.pageId = pageId
        self.title = title
        self.link = link
        self.leaf = leaf
        self.widgets = widgets
        self.widgets.forEach { $0.delegate = self }
    }

    init(xml xmlElement: GDataXMLElement?) {
        super.init()
        widgets = [OpenHABWidget]()
        for child in (xmlElement?.children())! {
            if let child = child as? GDataXMLElement {
            if !(child.name() == "widget") {
                if !(child.name() == "id") {
                    if let name = child.name() {
                        if propertyNames.contains(name) {
                            setValue(child.stringValue, forKey: child.name() ?? "")
                        }
                    }
                } else {
                    pageId = child.stringValue() ?? ""
                }
            } else {
                let newWidget = OpenHABWidget(xml: child)
                newWidget.delegate = self
                widgets.append(newWidget)

                // If widget have child widgets, cycle through them too
//                if Int(child.elements(forName: "widget") ?? 0) > 0 {
//                    for childChild: GDataXMLElement? in child.elements(forName: "widget") ?? [] {
//                        if child?.name() == "widget" {
//                            let newChildWidget = OpenHABWidget(xml: childChild) as? OpenHABWidget
//                            if newChildWidget != nil {
//                                newChildWidget?.delegate = self
//                                if let newChildWidget = newChildWidget {
//                                    widgets.append(newChildWidget)
//                                }
//                            }
//                        }
//                    }
//                }
            }
            }
        }
    }

    init(dictionary: [String: Any]) {
        super.init()
        widgets = [OpenHABWidget]()
        pageId = dictionary["id"] as? String ?? ""
        title = dictionary["title"] as? String ?? ""
        link = dictionary["link"] as? String ?? ""
        leaf = dictionary["leaf"] as? String ?? ""
        let widgetsArray = dictionary["widgets"] as? [[String: Any]?]
        for widgetDictionary in widgetsArray ?? [] {
            let newWidget = OpenHABWidget(dictionary: widgetDictionary!)
            newWidget.delegate = self
            widgets.append(newWidget)
            if widgetDictionary?["widgets"] != nil {
                let childWidgetsArray = widgetDictionary?["widgets"] as? [[String: Any]?]
                for childWidgetDictionary in childWidgetsArray ?? [] {
                    let newChildWidget = OpenHABWidget(dictionary: childWidgetDictionary!)
                    newChildWidget.delegate = self
                    widgets.append(newChildWidget)
                }
            }
        }
    }

    func sendCommand(_ item: OpenHABItem?, commandToSend command: String?) {
        if let name = item?.name {
            print("SitemapPage sending command \(command ?? "") to \(name)")
        }
        if delegate != nil {
            delegate?.sendCommand(item, commandToSend: command)
        }
    }
}
