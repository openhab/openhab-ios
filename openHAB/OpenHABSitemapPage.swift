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
import os.log

protocol OpenHABSitemapPageDelegate: NSObjectProtocol {
    func sendCommand(_ item: OpenHABItem?, commandToSend command: String?)
}

extension OpenHABSitemapPage {

    struct CodingData: Decodable {
        let pageId: String?
        let title: String?
        let link: String?
        let leaf: Bool?
        let widgets: [OpenHABWidget.CodingData]?

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
        let mappedWidgets = self.widgets?.map { $0.openHABWidget } ?? []
        return OpenHABSitemapPage(pageId: self.pageId ?? "", title: self.title ?? "", link: self.link ?? "", leaf: self.leaf ?? false, widgets: mappedWidgets)
    }
}

class OpenHABSitemapPage: NSObject, OpenHABWidgetDelegate {
    weak var delegate: OpenHABSitemapPageDelegate?
    var widgets: [OpenHABWidget] = []
    var pageId = ""
    var title = ""
    var link = ""
    var leaf = ""

    init(pageId: String, title: String, link: String, leaf: Bool, widgets: [OpenHABWidget]) {
        super.init()
        self.pageId = pageId
        self.title = title
        self.link = link
        self.leaf = leaf ? "true" : "false"
        var ws = [OpenHABWidget]()
        // This could be expressed recursively but this does the job on 2 levels 
        for w1 in widgets {
            ws.append(w1)
            for w2 in w1.widgets {
                ws.append(w2)
            }
        }
        self.widgets = ws
        self.widgets.forEach { $0.delegate = self }
    }

#if canImport(GDataXMLElement)
    init(xml xmlElement: GDataXMLElement?) {
        let propertyNames: Set = ["pageId", "title", "link", "leaf"]
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

            }
            }
        }
    }
#endif

    func sendCommand(_ item: OpenHABItem?, commandToSend command: String?) {
        if let name = item?.name {
            os_log("SitemapPage sending command %{PUBLIC}@ to %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, command ?? "", name)
        }
        if delegate != nil {
            delegate?.sendCommand(item, commandToSend: command)
        }
    }

    init(pageId: String, title: String, link: String, leaf: Bool, expandedWidgets: [OpenHABWidget]) {
        super.init()
        self.pageId = pageId
        self.title = title
        self.link = link
        self.leaf = leaf ? "true" : "false"
        self.widgets = expandedWidgets
        self.widgets.forEach { $0.delegate = self }
    }
}

extension OpenHABSitemapPage {
    func filter (_ isIncluded: (OpenHABWidget) throws -> Bool) rethrows -> OpenHABSitemapPage {
        return OpenHABSitemapPage(pageId: self.pageId,
                                  title: self.title,
                                  link: self.link,
                                  leaf: self.leaf == "true" ? true : false,
                                  expandedWidgets: try self.widgets.filter(isIncluded))
    }
}
