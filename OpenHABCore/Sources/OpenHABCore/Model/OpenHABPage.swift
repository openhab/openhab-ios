// Copyright (c) 2010-2026 Contributors to the openHAB project
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

public class OpenHABPage: NSObject, @unchecked Sendable {
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
        self.icon = icon
        var flattened = [OpenHABWidget]()
        flattened.flatten(widgets)
        self.widgets = flattened

        decorateWithSendCommand(self.widgets)
    }

    private func decorateWithSendCommand(_ widgets: [OpenHABWidget]) {
        for widget in widgets {
            widget.sendCommand = { [weak self] item, command in
                self?.sendCommand(item, commandToSend: command)
            }
            decorateWithSendCommand(widget.widgets)
        }
    }

    private func sendCommand(_ item: OpenHABItem?, commandToSend command: String?) {
        guard let item else { return }
        Logger.restAPI.info("SitemapPage sending command \(command.orEmpty) to \(item.name)")
        sendCommand?(item, command)
    }
}

public extension OpenHABPage {
    convenience init?(_ page: Components.Schemas.PageDTO?) {
        if let page {
            self.init(
                pageId: page.id.orEmpty,
                title: page.title.orEmpty,
                link: page.link.orEmpty,
                leaf: page.leaf ?? false,
                widgets: page.widgets?.compactMap { OpenHABWidget($0) } ?? [],
                icon: page.icon.orEmpty
            )
        } else {
            return nil
        }
    }

    func filter(_ isIncluded: (OpenHABWidget) throws -> Bool) rethrows -> OpenHABPage {
        try OpenHABPage(
            pageId: pageId,
            title: title,
            link: link,
            leaf: leaf,
            widgets: widgets.filter(isIncluded),
            icon: icon
        )
    }

    @discardableResult
    func apply(event: OpenHABSitemapWidgetEvent) -> SitemapWidgetEventApplicationResult {
        for widget in widgets {
            let result = widget.apply(event: event)
            if result != .notFound {
                return result
            }
        }
        return .notFound
    }
}
