// Copyright (c) 2010-2023 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Foundation
import Fuzi
import os.log

public class OpenHABSitemapPage: NSObject {
    public var sendCommand: ((_ item: OpenHABItem, _ command: String?) -> Void)?
    public var widgets: [OpenHABWidget] = []
    public var pageId = ""
    public var title = ""
    public var link = ""
    public var leaf = false
    public var icon = ""

    public init(pageId: String, title: String, link: String, leaf: Bool, widgets: [OpenHABWidget], icon: String) {
        super.init()
        self.pageId = pageId
        self.title = title
        self.link = link
        self.leaf = leaf
        var tempWidgets = [OpenHABWidget]()
        tempWidgets.flatten(widgets)
        self.widgets = tempWidgets
        self.widgets.forEach {
            $0.sendCommand = { [weak self] item, command in
                self?.sendCommand(item, commandToSend: command)
            }
        }
        self.icon = icon
    }

    public init(xml xmlElement: XMLElement) {
        super.init()
        for child in xmlElement.children {
            switch child.tag {
            case "widget": widgets.append(OpenHABWidget(xml: child))
            case "id": pageId = child.stringValue
            case "title": title = child.stringValue
            case "link": link = child.stringValue
            case "leaf": leaf = child.stringValue == "true" ? true : false
            case "icon": icon = child.stringValue
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

    private func sendCommand(_ item: OpenHABItem?, commandToSend command: String?) {
        guard let item else { return }

        os_log("SitemapPage sending command %{PUBLIC}@ to %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, command.orEmpty, item.name)
        sendCommand?(item, command)
    }
}

public extension OpenHABSitemapPage {
    func filter(_ isIncluded: (OpenHABWidget) throws -> Bool) rethrows -> OpenHABSitemapPage {
        let filteredOpenHABSitemapPage = try OpenHABSitemapPage(
            pageId: pageId,
            title: title,
            link: link,
            leaf: leaf,
            widgets: widgets.filter(isIncluded),
            icon: icon
        )
        return filteredOpenHABSitemapPage
    }
}

public extension OpenHABSitemapPage {
    struct CodingData: Decodable {
        let pageId: String?
        let title: String?
        let link: String?
        let leaf: Bool?
        let widgets: [OpenHABWidget.CodingData]?
        let icon: String?

        private enum CodingKeys: String, CodingKey {
            case pageId = "id"
            case title
            case link
            case leaf
            case widgets
            case icon
        }
    }
}

public extension OpenHABSitemapPage.CodingData {
    var openHABSitemapPage: OpenHABSitemapPage {
        let mappedWidgets = widgets?.map(\.openHABWidget) ?? []
        return OpenHABSitemapPage(pageId: pageId.orEmpty, title: title.orEmpty, link: link.orEmpty, leaf: leaf ?? false, widgets: mappedWidgets, icon: icon.orEmpty)
    }
}
