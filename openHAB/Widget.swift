//
//  Widget.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 15.11.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation

protocol Widget: AnyObject {
    //  Recursive constraints possible as of Swift 4.1
    associatedtype ChildWidget: Widget where ChildWidget.Type == Type

    var sendCommand: ((_ item: OpenHABItem, _ command: String?) -> Void)? { get set }
    var widgetId: String { get set }
    var label: String { get set }
    var icon: String { get set }
    var type: String { get set }
    var url: String { get set }
    var period: String { get set }
    var minValue: Double { get set }
    var maxValue: Double { get set }
    var step: Double { get set }
    var refresh: Int { get set }
    var height: Double { get set }
    var isLeaf: Bool { get set }
    var iconColor: String { get set }
    var labelcolor: String { get set }
    var valuecolor: String { get set }
    var service: String { get set }
    var state: String { get set }
    var text: String { get set }
    var legend: Bool { get set }
    var encoding: String { get set }
    var item: OpenHABItem? { get set }
    var linkedPage: OpenHABLinkedPage? { get set }
    var mappings: [OpenHABWidgetMapping] { get set }
    var image: UIImage? { get set }
    var widgets: [ChildWidget] { get set }

 }


 // Recursive parsing of nested widget structure
 extension Array where Element: Widget  {
    mutating func flattenW(_ widgets: [Widget]) {
        for widget in widgets {
            Self.append(widget)
            Self.flatten(widget.widgets)
        }
    }
 }
