//
//  SitemapPage.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 15.11.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation

protocol SitemapPage {
    associatedtype T: Widget
    var sendCommand: ((_ item: OpenHABItem, _ command: String?) -> Void)? {get set}
    var widgets: [T] {get set}
    var pageId: String {get set}
    var title:  String {get set}
    var link: String {get set}
    var leaf: Bool {get set}
    func flattenWidgets()

}

 extension SitemapPage {
    func flattenWidgets() {
        var tempWidgets = [T]()
        tempWidgets.flattenW(widgets)
        widgets = tempWidgets
    }
 }
