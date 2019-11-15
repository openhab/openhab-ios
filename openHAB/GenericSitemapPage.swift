//
//  GenericSitemapPage.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 15.11.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

class GenericOpenHABSitemapPage<T>: NSObject, SitemapPage {
    
    var sendCommand: ((_ item: OpenHABItem, _ command: String?) -> Void)?
    var widgets: [T] = []
    var pageId = ""
    var title = ""
    var link = ""
    var leaf = false
    
    init(pageId: String, title: String, link: String, leaf: Bool, widgets: [T]) {
        super.init()
        self.pageId = pageId
        self.title = title
        self.link = link
        self.leaf = leaf
        self.flattenWidgets()
        self.widgets.forEach {
            $0.sendCommand = { [weak self] item, command in
                self?.sendCommand(item, commandToSend: command)
            }
        }
    }

    init(xml xmlElement: XMLElement) {
        super.init()
        for child in xmlElement.children {
            switch child.tag {
            case "widget": widgets.append(OpenHABWidget(xml: child))
            case "id": pageId = child.stringValue
            case "title": title = child.stringValue
            case "link": link = child.stringValue
            case "leaf": leaf = child.stringValue == "true" ? true : false
            default: break
            }
        }
        var tempWidgets = [OpenHABWidget]()
        tempWidgets.flatten(widgets)
        widgets = tempWidgets
        widgets.forEach {
            $0.sendCommand = { [weak self] item, command in
                self?.sendCommand(item, commandToSend: command)
            }
        }
    }

    init(pageId: String, title: String, link: String, leaf: Bool, expandedWidgets: [T]) {
        super.init()
        self.pageId = pageId
        self.title = title
        self.link = link
        self.leaf = leaf
        widgets = expandedWidgets
        widgets.forEach {
            $0.sendCommand = { [weak self] item, command in
                self?.sendCommand(item, commandToSend: command)
            }
        }
    }

    private func sendCommand(_ item: OpenHABItem?, commandToSend command: String?) {
        guard let item = item else { return }

        os_log("SitemapPage sending command %{PUBLIC}@ to %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, command ?? "", item.name)
        sendCommand?(item, command)
    }
    
}

extension GenericOpenHABSitemapPage {
    func filter(_ isIncluded: (T) throws -> Bool) rethrows -> Self {
        let filteredOpenHABSitemapPage = Self.init(pageId: pageId,
                                                            title: title,
                                                            link: link,
                                                            leaf: leaf,
                                                            expandedWidgets: try widgets.filter(isIncluded))
        return filteredOpenHABSitemapPage
    }
}

extension GenericOpenHABSitemapPage {
    struct CodingData: Decodable {
        let pageId: String?
        let title: String?
        let link: String?
        let leaf: Bool?
        let widgets: [T.CodingData]?

        private enum CodingKeys: String, CodingKey {
            case pageId = "id"
            case title
            case link
            case leaf
            case widgets
        }
    }
}

extension GenericOpenHABSitemapPage.CodingData {
    var openHABSitemapPage: Self {
        let mappedWidgets = widgets?.map { $0.openHABWidget } ?? []
        return Self(pageId: pageId ?? "", title: title ?? "", link: link ?? "", leaf: leaf ?? false, widgets: mappedWidgets)
    }
}
