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

import Alamofire
#if canImport(Combine)
import Combine
#endif
import Foundation
import MapKit
import OpenHABCore
import os.log

enum WidgetTypeEnum {
    case switcher(Bool)
    case slider //
    case segmented(Int)
    case unassigned
    case rollershutter
    case frame
    case setpoint
    case selection
    case colorpicker
    case chart
    case image
    case video
    case webview
    case mapview

    var boolState: Bool {
        guard case let .switcher(value) = self else { return false }
        return value
    }
}

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
class ObservableOpenHABWidget: NSObject, MKAnnotation, Identifiable, ObservableObject {
    var id: String = ""

    var sendCommand: ((_ item: OpenHABItem, _ command: String?) -> Void)?
    var widgetId = ""
    @Published var label = ""
    var icon = ""
    var type = ""
    var url = ""
    var period = ""
    var minValue = 0.0
    var maxValue = 100.0
    var step = 1.0
    var refresh = 0
    var height = 44.0
    var isLeaf = false
    var iconColor = ""
    var labelcolor = ""
    var valuecolor = ""
    var service = ""
    @Published var state = ""
    var text = ""
    var legend: Bool?
    var encoding = ""
    @Published var item: OpenHABItem?
    var linkedPage: OpenHABPage?
    var mappings: [OpenHABWidgetMapping] = []
    var image: UIImage?
    var widgets: [ObservableOpenHABWidget] = []
    public var visibility = true
    public var switchSupport = false
    public var forceAsItem: Bool?

    @Published var stateEnumBinding: WidgetTypeEnum = .unassigned

    // Text prior to "["
    var labelText: String? {
        let array = label.components(separatedBy: "[")
        return array[0].trimmingCharacters(in: .whitespaces)
    }

    // Text between square brackets
    public var labelValue: String? {
        let pattern = /\[(.*?)\]/.dotMatchesNewlines()
        guard let firstMatch = label.firstMatch(of: pattern) else { return nil }
        return String(firstMatch.1)
    }

    var coordinate: CLLocationCoordinate2D {
        item?.stateAsLocation()?.coordinate ?? kCLLocationCoordinate2DInvalid
    }

    var mappingsOrItemOptions: [OpenHABWidgetMapping] {
        if mappings.isEmpty, let commandOptions = item?.commandDescription?.commandOptions {
            commandOptions.map { OpenHABWidgetMapping(command: $0.command, label: $0.label ?? "") }
        } else if mappings.isEmpty, let stateOptions = item?.stateDescription?.options {
            stateOptions.map { OpenHABWidgetMapping(command: $0.value, label: $0.label) }
        } else {
            mappings
        }
    }

    public var stateValueAsBool: Bool? {
        item?.state?.parseAsBool()
    }

    public var stateValueAsBrightness: Int? {
        item?.state?.parseAsBrightness()
    }

    public var stateValueAsUIColor: UIColor? {
        item?.state?.parseAsUIColor()
    }

    public var stateValueAsNumberState: NumberState? {
        item?.state?.parseAsNumber(format: item?.stateDescription?.numberPattern)
    }

    var adjustedValue: Double {
        if let item {
            adj(item.stateAsDouble())
        } else {
            minValue
        }
    }

    var stateEnum: WidgetTypeEnum {
        switch type {
        case "Frame":
            .frame
        case "Switch":
            // Reflecting the discussion held in https://github.com/openhab/openhab-core/issues/952
            if !mappings.isEmpty {
                .segmented(Int(mappingIndex(byCommand: item?.state) ?? -1))
            } else if item?.isOfTypeOrGroupType(.switchItem) ?? false {
                .switcher(item?.state == "ON" ? true : false)
            } else if item?.isOfTypeOrGroupType(.rollershutter) ?? false {
                .rollershutter
            } else if !mappingsOrItemOptions.isEmpty {
                .segmented(Int(mappingIndex(byCommand: item?.state) ?? -1))
            } else {
                .switcher(item?.state == "ON" ? true : false)
            }
        case "Setpoint":
            .setpoint
        case "Slider":
            .slider // (adjustedValue)
        case "Selection":
            .selection
        case "Colorpicker":
            .colorpicker
        case "Chart":
            .chart
        case "Image":
            .image
        case "Video":
            .video
        case "Webview":
            .webview
        case "Mapview":
            .mapview
        default:
            .unassigned
        }
    }

    public func sendItemUpdate(state: NumberState?) {
        guard let item, let state else {
            os_log("ItemUpdate for Item or State = nil", log: .default, type: .info)
            return
        }
        if item.isOfTypeOrGroupType(.numberWithDimension) {
            // For number items, include unit (if present) in command
            sendCommand(state.toString(locale: Locale(identifier: "US")))
        } else {
            // For all other items, send the plain value
            sendCommand(state.stringValue)
        }
    }

    func sendCommandDouble(_ command: Double) {
        sendCommand(String(command))
    }

    func sendCommand(_ command: String?) {
        guard let item else {
            os_log("Command for Item = nil", log: .default, type: .info)
            return
        }
        guard let sendCommand else {
            os_log("sendCommand closure not set", log: .default, type: .info)
            return
        }
        sendCommand(item, command)
    }

    func mappingIndex(byCommand command: String?) -> Int? {
        mappingsOrItemOptions.firstIndex { $0.command == command }
    }

    private func adj(_ raw: Double) -> Double {
        var valueAdjustedToStep = floor((raw - minValue) / step) * step
        valueAdjustedToStep += minValue
        return valueAdjustedToStep.clamped(to: minValue ... maxValue)
    }
}

extension ObservableOpenHABWidget {
    // This is an ugly initializer
    convenience init(widgetId: String, label: String, icon: String, type: String, url: String?, period: String?, minValue: Double?, maxValue: Double?, step: Double?, refresh: Int?, height: Double?, isLeaf: Bool?, iconColor: String?, labelColor: String?, valueColor: String?, service: String?, state: String?, text: String?, legend: Bool?, encoding: String?, item: OpenHABItem?, linkedPage: OpenHABPage?, mappings: [OpenHABWidgetMapping], widgets: [ObservableOpenHABWidget], forceAsItem: Bool?) {
        self.init()

        id = widgetId

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
        self.height = height ?? 44.0
        self.isLeaf = isLeaf ?? false
        self.iconColor = iconColor ?? ""
        labelcolor = labelColor ?? ""
        valuecolor = valueColor ?? ""
        self.service = service ?? ""
        self.state = state ?? ""
        self.text = text ?? ""
        self.legend = legend
        self.encoding = encoding ?? ""
        self.item = item
        self.linkedPage = linkedPage
        self.mappings = mappings
        self.widgets = widgets

        // Sanitize minValue, maxValue and step: min <= max, step >= 0
        self.maxValue = max(self.minValue, self.maxValue)
        self.step = abs(self.step)

        self.forceAsItem = forceAsItem

        stateEnumBinding = stateEnum
    }
}

extension ObservableOpenHABWidget {
    public struct CodingData: Decodable {
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
        let isLeaf: Bool?
        let iconColor: String?
        let labelcolor: String?
        let valuecolor: String?
        let service: String?
        let state: String?
        let text: String?
        let legend: Bool?
        let encoding: String?
        let groupType: String?
        let item: OpenHABItem.CodingData?
        let linkedPage: OpenHABPage.CodingData?
        let mappings: [OpenHABWidgetMapping]
        let widgets: [ObservableOpenHABWidget.CodingData]
        let forceAsItem: Bool?
    }
}

extension ObservableOpenHABWidget.CodingData {
    var openHABWidget: ObservableOpenHABWidget {
        let mappedWidgets = widgets.map(\.openHABWidget)
        // swiftlint:disable:next line_length
        return ObservableOpenHABWidget(widgetId: widgetId, label: label, icon: icon, type: type, url: url, period: period, minValue: minValue, maxValue: maxValue, step: step, refresh: refresh, height: height, isLeaf: isLeaf, iconColor: iconColor, labelColor: labelcolor, valueColor: valuecolor, service: service, state: state, text: text, legend: legend, encoding: encoding, item: item?.openHABItem, linkedPage: linkedPage?.openHABSitemapPage, mappings: mappings, widgets: mappedWidgets, forceAsItem: forceAsItem)
    }
}

//  Recursive parsing of nested widget structure
extension [ObservableOpenHABWidget] {
    mutating func flatten(_ widgets: [Element]) {
        for widget in widgets {
            append(widget)
            flatten(widget.widgets)
        }
    }
}
