// Copyright (c) 2010-2024 Contributors to the openHAB project
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
import os.log

public class OpenHABPage: NSObject {
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
        for widget in self.widgets {
            widget.sendCommand = { [weak self] item, command in
                self?.sendCommand(item, commandToSend: command)
            }
        }
        self.icon = icon
    }

    private func sendCommand(_ item: OpenHABItem?, commandToSend command: String?) {
        guard let item else { return }

        os_log("SitemapPage sending command %{PUBLIC}@ to %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, command.orEmpty, item.name)
        sendCommand?(item, command)
    }
}

public extension OpenHABPage {
    func filter(_ isIncluded: (OpenHABWidget) throws -> Bool) rethrows -> OpenHABPage {
        let filteredOpenHABSitemapPage = try OpenHABPage(
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

public extension OpenHABPage {
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

public extension OpenHABPage.CodingData {
    var openHABSitemapPage: OpenHABPage {
        let mappedWidgets = widgets?.map(\.openHABWidget) ?? []
        return OpenHABPage(pageId: pageId.orEmpty, title: title.orEmpty, link: link.orEmpty, leaf: leaf ?? false, widgets: mappedWidgets, icon: icon.orEmpty)
    }
}
