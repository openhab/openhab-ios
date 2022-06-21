// Copyright (c) 2010-2022 Contributors to the openHAB project
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
import OpenHABCore
import os.log

class ObservableOpenHABSitemapPage: NSObject {
    var sendCommand: ((_ item: OpenHABItem, _ command: String?) -> Void)?
    var widgets: [ObservableOpenHABWidget] = []
    var pageId = ""
    var title = ""
    var link = ""
    var leaf = false

    init(pageId: String, title: String, link: String, leaf: Bool, widgets: [ObservableOpenHABWidget]) {
        super.init()
        self.pageId = pageId
        self.title = title
        self.link = link
        self.leaf = leaf
        var tempWidgets = [ObservableOpenHABWidget]()
        tempWidgets.flatten(widgets)
        self.widgets = tempWidgets
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
            case "widget": widgets.append(ObservableOpenHABWidget(xml: child))
            case "id": pageId = child.stringValue
            case "title": title = child.stringValue
            case "link": link = child.stringValue
            case "leaf": leaf = child.stringValue == "true" ? true : false
            default: break
            }
        }
        var tempWidgets = [ObservableOpenHABWidget]()
        tempWidgets.flatten(widgets)
        widgets = tempWidgets
        widgets.forEach {
            $0.sendCommand = { [weak self] item, command in
                self?.sendCommand(item, commandToSend: command)
            }
        }
    }

    init(pageId: String, title: String, link: String, leaf: Bool, expandedWidgets: [ObservableOpenHABWidget]) {
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

extension ObservableOpenHABSitemapPage {
    struct CodingData: Decodable {
        let pageId: String?
        let title: String?
        let link: String?
        let leaf: Bool?
        let widgets: [ObservableOpenHABWidget.CodingData]?

        private enum CodingKeys: String, CodingKey {
            case pageId = "id"
            case title
            case link
            case leaf
            case widgets
        }
    }
}

extension ObservableOpenHABSitemapPage.CodingData {
    var openHABSitemapPage: ObservableOpenHABSitemapPage {
        let mappedWidgets = widgets?.map(\.openHABWidget) ?? []
        return ObservableOpenHABSitemapPage(pageId: pageId ?? "", title: title ?? "", link: link ?? "", leaf: leaf ?? false, widgets: mappedWidgets)
    }
}

extension ObservableOpenHABSitemapPage {
    func filter(_ isIncluded: (ObservableOpenHABWidget) throws -> Bool) rethrows -> ObservableOpenHABSitemapPage {
        let filteredOpenHABSitemapPage = ObservableOpenHABSitemapPage(
            pageId: pageId,
            title: title,
            link: link,
            leaf: leaf,
            expandedWidgets: try widgets.filter(isIncluded)
        )
        return filteredOpenHABSitemapPage
    }
}
