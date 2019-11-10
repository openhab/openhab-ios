// Copyright (c) 2010-2019 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

#if canImport(Combine)
import Alamofire
import Combine
#endif
import Foundation
#if !os(watchOS)
import Fuzi
#endif
import MapKit
import os.log

protocol Widget: AnyObject {
    associatedtype ChildWidget: Widget
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

class OpenHABWidget: NSObject, MKAnnotation, ObservableObject, Identifiable {
    var id: String = ""

    var sendCommand: ((_ item: OpenHABItem, _ command: String?) -> Void)?
    var widgetId = ""
    var label = ""
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
    var state = ""
    var text = ""
    var legend = false
    var encoding = ""
    var item: OpenHABItem?
    var linkedPage: OpenHABLinkedPage?
    var mappings: [OpenHABWidgetMapping] = []
    var image: UIImage?
    var widgets: [OpenHABWidget] = []

    @Published var stateBinding: Bool = false

    // Text prior to "["
    var labelText: String? {
        let array = label.components(separatedBy: "[")
        return array[0].trimmingCharacters(in: .whitespaces)
    }

    // Text between square brackets
    var labelValue: String? {
        // Swift 5 raw strings
        let regex = try? NSRegularExpression(pattern: #"\[(.*?)\]"#, options: [])
        guard let match = regex?.firstMatch(in: label, options: [], range: NSRange(location: 0, length: (label as NSString).length)) else { return nil }
        guard let range = Range(match.range(at: 1), in: label) else { return nil }
        return String(label[range])
    }

    var coordinate: CLLocationCoordinate2D {
        return item?.stateAsLocation()?.coordinate ?? kCLLocationCoordinate2DInvalid
    }

    var mappingsOrItemOptions: [OpenHABWidgetMapping] {
        if mappings.isEmpty, let itemOptions = item?.stateDescription?.options {
            return itemOptions.map { OpenHABWidgetMapping(command: $0.value, label: $0.label) }
        } else {
            return mappings
        }
    }

    func sendCommandDouble(_ command: Double) {
        sendCommand(String(command))
    }

    func sendCommand(_ command: String?) {
        guard let item = item else {
            os_log("Command for Item = nil", log: .default, type: .info)
            return
        }
        guard let sendCommand = sendCommand else {
            os_log("sendCommand closure not set", log: .default, type: .info)
            return
        }
        sendCommand(item, command)
    }

    func mappingIndex(byCommand command: String?) -> Int? {
        return mappingsOrItemOptions.firstIndex { $0.command == command }
    }
}

extension OpenHABWidget {
    // This is an ugly initializer
    convenience init(widgetId: String, label: String, icon: String, type: String, url: String?, period: String?, minValue: Double?, maxValue: Double?, step: Double?, refresh: Int?, height: Double?, isLeaf: Bool?, iconColor: String?, labelColor: String?, valueColor: String?, service: String?, state: String?, text: String?, legend: Bool?, encoding: String?, item: OpenHABItem?, linkedPage: OpenHABLinkedPage?, mappings: [OpenHABWidgetMapping], widgets: [OpenHABWidget]) {
        self.init()
        id = widgetId
        stateBinding = state == "ON" ? true : false

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
        self.legend = legend ?? false
        self.encoding = encoding ?? ""
        self.item = item
        self.linkedPage = linkedPage
        self.mappings = mappings
        self.widgets = widgets

        // Sanitize minValue, maxValue and step: min <= max, step >= 0
        self.maxValue = max(self.minValue, self.maxValue)
        self.step = abs(self.step)

        _ = statePublisher
            .receive(on: RunLoop.main)
            .map { value -> String in
                value ? "ON" : "OFF"
            }
            .sink { receivedValue in
                // sink is the subscriber and terminates the pipeline
                self.sendCommand(receivedValue)
                print("Sending to: \(widgetId) command: \(receivedValue)")
            }
    }

    #if !os(watchOS)
    convenience init(xml xmlElement: XMLElement) {
        self.init()
        id = widgetId
        stateBinding = state == "ON" ? true : false

        for child in xmlElement.children {
            switch child.tag {
            case "widgetId": widgetId = child.stringValue
            case "label": label = child.stringValue
            case "type": type = child.stringValue
            case "icon": icon = child.stringValue
            case "url": url = child.stringValue
            case "period": period = child.stringValue
            case "iconColor": iconColor = child.stringValue
            case "labelcolor": labelcolor = child.stringValue
            case "valuecolor": valuecolor = child.stringValue
            case "service": service = child.stringValue
            case "state": state = child.stringValue
            case "text": text = child.stringValue
            case "height": height = Double(child.stringValue) ?? 44.0
            case "encoding": encoding = child.stringValue
            // Double
            case "minValue": minValue = Double(child.stringValue) ?? 0.0
            case "maxValue": maxValue = Double(child.stringValue) ?? 0.0
            case "step": step = Double(child.stringValue) ?? 0.0
            // Bool
            case "isLeaf": isLeaf = child.stringValue == "true" ? true : false
            case "legend": legend = child.stringValue == "true" ? true : false
            // Int
            case "refresh": refresh = Int(child.stringValue) ?? 0
            // Embedded
            case "widget": widgets.append(OpenHABWidget(xml: child))
            case "item": item = OpenHABItem(xml: child)
            case "mapping": mappings.append(OpenHABWidgetMapping(xml: child))
            case "linkedPage": linkedPage = OpenHABLinkedPage(xml: child)
            default:
                break
            }
        }
    }
    #endif

    private var statePublisher: AnyPublisher<Bool, Never> {
        $stateBinding
            .debounce(for: 0.1, scheduler: RunLoop.main)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}

// @available(iOS 13, watchOS 6, *)
// class NewOpenHABWidget: OpenHABWidget, ObservableObject, Identifiable {
//
//    var id: String
//
//    private var commandOperation: Alamofire.Request?
//
//    @Published var stateBinding: String
//
//    private var statePublisher: AnyPublisher<String, Never> {
//        $stateBinding
//            .debounce(for: 0.1, scheduler: RunLoop.main)
//            .removeDuplicates()
//            .eraseToAnyPublisher()
//    }
//    override init(widgetId: String, label: String, icon: String, type: String, url: String?, period: String?, minValue: Double?, maxValue: Double?, step: Double?, refresh: Int?, height: Double?, isLeaf: Bool?, iconColor: String?, labelColor: String?, valueColor: String?, service: String?, state: String?, text: String?, legend: Bool?, encoding: String?, item: OpenHABItem?, linkedPage: OpenHABLinkedPage?, mappings: [OpenHABWidgetMapping], widgets: [OpenHABWidget]) {
//        self.id = widgetId
//        self.stateBinding = state ?? ""
//
//
//
//        super.init(widgetId: widgetId, label: label, icon: icon, type: type, url: url, period: period, minValue: minValue, maxValue: maxValue, step: step, refresh: refresh, height: height, isLeaf: isLeaf, iconColor: iconColor, labelColor: labelColor, valueColor: valueColor, service: service, state: state, text: text, legend: legend, encoding: encoding, item: item, linkedPage: linkedPage, mappings: mappings, widgets: widgets)
//
//
//
//         _ = statePublisher
//             .receive(on: RunLoop.main)
////             .map { value -> String in
////                 value ? "ON" : "OFF"
////             }
//             .sink { receivedValue in
//                 // sink is the subscriber and terminates the pipeline
//                 self.sendCommand(receivedValue)
//                 print("Sending to: \(widgetId) command: \(receivedValue)")
//             }
//     }
//
// }

extension OpenHABWidget {
    struct CodingData: Decodable {
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
        let linkedPage: OpenHABLinkedPage?
        let mappings: [OpenHABWidgetMapping]
        let widgets: [OpenHABWidget.CodingData]
    }
}

// swiftlint:disable line_length
extension OpenHABWidget.CodingData {
    var openHABWidget: OpenHABWidget {
        let mappedWidgets = widgets.map { $0.openHABWidget }
        return OpenHABWidget(widgetId: widgetId, label: label, icon: icon, type: type, url: url, period: period, minValue: minValue, maxValue: maxValue, step: step, refresh: refresh, height: height, isLeaf: isLeaf, iconColor: iconColor, labelColor: labelcolor, valueColor: valuecolor, service: service, state: state, text: text, legend: legend, encoding: encoding, item: item?.openHABItem, linkedPage: linkedPage, mappings: mappings, widgets: mappedWidgets)
    }
}

//  Recursive parsing of nested widget structure
extension Array where Element == OpenHABWidget {
    mutating func flatten(_ widgets: [Element]) {
        for widget in widgets {
            append(widget)
            flatten(widget.widgets)
        }
    }
}
