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

@_exported import Combine
import Foundation
@_exported import MapKit
import os.log

public enum WidgetTypeEnum {
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

    public var boolState: Bool {
        guard case let .switcher(value) = self else { return false }
        return value
    }
}

public class OpenHABWidget: NSObject, MKAnnotation, Identifiable, ObservableObject {
    public enum WidgetType: String, Decodable {
        case chart = "Chart"
        case colorpicker = "Colorpicker"
        case defaultWidget = "Default"
        case frame = "Frame"
        case group = "Group"
        case image = "Image"
        case input = "Input"
        case mapview = "Mapview"
        case selection = "Selection"
        case setpoint = "Setpoint"
        case slider = "Slider"
        case switchWidget = "Switch"
        case text = "Text"
        case video = "Video"
        case webview = "Webview"
        case colortemperaturepicker = "Colortemperaturepicker"
        case buttongrid = "Buttongrid"
        case button = "Button"
        case unknown = "Unknown"
    }

    public enum LabelSource: String, Decodable {
        case sitemapDefinition = "SITEMAP_WIDGET"
        case itemLabel = "ITEM_LABEL"
        case itemName = "ITEM_NAME"
        case unknown = "UNKNOWN"
    }

    public enum InputHint: String, Decodable {
        case text, number, date, time, dateTime, unknown

        public init(rawValue: String) {
            switch rawValue.lowercased() {
            case "text":
                self = .text
            case "number":
                self = .number
            case "date":
                self = .date
            case "time":
                self = .time
            case "datetime", "dateTime":
                self = .dateTime
            default:
                self = .unknown
            }
        }
    }

    public var id = ""

    public var sendCommand: ((_ item: OpenHABItem, _ command: String?) -> Void)?
    public var widgetId = ""
    @Published public var label = ""
    @Published public var icon = ""

    public var type: WidgetType = .unknown
    public var url = ""
    public var period = ""
    public var minValue = 0.0
    public var maxValue = 100.0
    public var step = 1.0
    public var refresh = 0
    public var height: Double?
    public var isLeaf = false
    @Published public var iconColor = ""
    @Published public var labelcolor = ""
    @Published public var valuecolor = ""
    public var service = ""
    @Published public var state = ""
    public var text = ""
    public var legend: Bool?
    public var inputHint = InputHint.unknown
    public var encoding = ""
    public var forceAsItem: Bool?
    @Published public var item: OpenHABItem?
    public var linkedPage: OpenHABPage?
    public var mappings: [OpenHABWidgetMapping] = []
    public var widgets: [OpenHABWidget] = []
    public var visibility = true
    public var unit: String?
    public var pattern: String?
    @Published public var staticIcon: Bool?
    public var switchSupport = false
    public var labelSource = LabelSource.unknown
    public var releaseOnly: Bool?
    public var row: Int?
    public var column: Int?
    public var releaseCommand: String?
    public var command: String?
    public var stateless: Bool?
    public var readOnly: Bool? {
        item?.stateDescription?.readOnly
    }

    public var yAxisDecimalPattern: String?

    @Published public var stateEnumBinding: WidgetTypeEnum = .unassigned

    // Text prior to "["
    public var labelText: String? {
        let array = label.components(separatedBy: "[")
        return array[0].trimmingCharacters(in: .whitespaces)
    }

    // Text between square brackets
    public var labelValue: String? {
        let pattern = /\[(.*?)\]/.dotMatchesNewlines()
        guard let firstMatch = label.firstMatch(of: pattern) else { return nil }
        return String(firstMatch.1)
    }

    public var coordinate: CLLocationCoordinate2D {
        item?.stateAsLocation()?.coordinate ?? kCLLocationCoordinate2DInvalid
    }

    public var mappingsOrItemOptions: [OpenHABWidgetMapping] {
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
        if state != "" {
            state.parseAsNumber(format: item?.stateDescription?.numberPattern)
        } else {
            item?.state?.parseAsNumber(format: item?.stateDescription?.numberPattern)
        }
    }

    public var adjustedValue: Double {
        if let item {
            adj(item.stateAsDouble())
        } else {
            minValue
        }
    }

    public var stateEnum: WidgetTypeEnum {
        switch type {
        case .frame:
            .frame
        case .switchWidget:
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
        case .setpoint:
            .setpoint
        case .slider:
            .slider
        case .selection:
            .selection
        case .colorpicker:
            .colorpicker
        case .chart:
            .chart
        case .image:
            .image
        case .video:
            .video
        case .webview:
            .webview
        case .mapview:
            .mapview
        default:
            .unassigned
        }
    }

    public func sendItemUpdate(state: NumberState?) {
        guard let item, let state else {
            Logger.restAPI.info("ItemUpdate for Item or State = nil")
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

    public func sendCommandDouble(_ command: Double) {
        sendCommand(String(command))
    }

    public func sendCommand(_ command: String?) {
        guard let item else {
            Logger.restAPI.info("Command for Item = nil")
            return
        }
        guard let sendCommand else {
            Logger.restAPI.info("sendCommand closure not set")
            return
        }
        sendCommand(item, command)
    }

    public func mappingIndex(byCommand command: String?) -> Int? {
        mappingsOrItemOptions.firstIndex { $0.command == command }
    }

    public func mapCommandtoIndex(with command: String?) -> Int {
        Int(mappingIndex(byCommand: command) ?? 0)
    }

    public func iconState() -> String? {
        guard let item, let itemState = item.state else { return nil }
        guard !itemState.isNoneIcon else { return nil }
        if item.isOfTypeOrGroupType(.color) {
            // For items that control a color item fetch the correct icon
            if type == .slider || (type == .switchWidget && mappings.isEmpty) {
                if let brightness = itemState.parseAsBrightness() {
                    let brightness = String(brightness)
                    if type == .switchWidget {
                        return brightness == "0" ? "OFF" : "ON"
                    } else {
                        return brightness
                    }
                } else {
                    return "OFF"
                }
            } else if let color = itemState.parseAsUIColor() {
                return "#\(color.hexString ?? "000000")"
            }
        } else if item.isOfTypeOrGroupType(.number) || item.isOfTypeOrGroupType(.numberWithDimension) {
            let numberState = itemState.parseAsNumber(format: item.stateDescription?.numberPattern)
            return numberState.toString(locale: Locale(identifier: "US"))
        } else if type == .switchWidget, mappings.isEmpty, !item.isOfTypeOrGroupType(.rollershutter) {
            // For switch items without mappings (just ON and OFF) that control a dimmer item
            // and which are not ON or OFF already, set the state to "OFF" instead of 0
            // or to "ON" to fetch the correct icon
            return (itemState == "0" || itemState == "OFF") ? "OFF" : "ON"
        }
        return itemState
    }

    private func adj(_ raw: Double) -> Double {
        var valueAdjustedToStep = floor((raw - minValue) / step) * step
        valueAdjustedToStep += minValue
        return valueAdjustedToStep.clamped(to: minValue ... maxValue)
    }

    public func generateImageResult(rootUrl: String,
                                    chartStyle: ChartStyle = .light) -> ImagePayload {
        print("widget yAxisDecimalPattern: \(yAxisDecimalPattern ?? "")")

        switch type {
        case .chart:
            guard let url = Endpoint.chart(
                rootUrl: rootUrl,
                period: period,
                type: item?.type,
                service: service,
                name: item?.name,
                legend: legend,
                theme: chartStyle,
                forceAsItem: forceAsItem,
                yAxisDecimalPattern: yAxisDecimalPattern
            ).url else {
                Logger.restAPI.error("Failed to generate chart URL")
                return .empty
            }
            return .link(url: url)

        case .image:
            if let item {
                return item.getImagePayload()
            }
            guard let url = URL(string: url) else {
                Logger.restAPI.error("Invalid image URL: \(self.url)")
                return .empty
            }
            return .link(url: url)

        default:
            return .empty
        }
    }
}

public extension OpenHABWidget {
    // This is an ugly initializer
    convenience init(widgetId: String,
                     label: String,
                     icon: String,
                     type: WidgetType,
                     url: String?,
                     period: String?,
                     minValue: Double?,
                     maxValue: Double?,
                     step: Double?,
                     refresh: Int?,
                     height: Double?,
                     isLeaf: Bool?,
                     iconColor: String?,
                     labelColor: String?,
                     valueColor: String?,
                     service: String?,
                     state: String?,
                     text: String?,
                     legend: Bool?,
                     inputHint: InputHint?,
                     encoding: String?,
                     item: OpenHABItem?,
                     linkedPage: OpenHABPage?,
                     mappings: [OpenHABWidgetMapping],
                     widgets: [OpenHABWidget],
                     visibility: Bool?,
                     switchSupport: Bool?,
                     forceAsItem: Bool?,
                     labelSource: LabelSource = .unknown,
                     releaseOnly: Bool? = nil,
                     row: Int? = nil,
                     column: Int? = nil,
                     releaseCommand: String? = nil,
                     command: String? = nil,
                     stateless: Bool? = nil,
                     staticIcon: Bool? = nil,
                     unit: String? = nil,
                     pattern: String? = nil,
                     yAxisDecimalPattern: String? = nil) {
        self.init()
        id = widgetId
        self.widgetId = widgetId
        self.label = label
        self.type = type
        self.icon = icon
        self.url = url ?? ""
        self.period = period ?? ""

        self.step = step ?? 1.0
        // Consider a minimal refresh rate of 100 ms, but 0 is special and means 'no refresh'
        if let refreshVal = refresh, refreshVal > 0 {
            self.refresh = max(100, refreshVal)
        } else {
            self.refresh = 0
        }
        self.height = height
        self.isLeaf = isLeaf ?? false
        self.iconColor = iconColor ?? ""
        labelcolor = labelColor ?? ""
        valuecolor = valueColor ?? ""
        self.service = service ?? ""
        self.state = state ?? ""
        self.text = text ?? ""
        self.legend = legend
        self.inputHint = inputHint ?? .text
        self.encoding = encoding ?? ""
        self.item = item
        self.linkedPage = linkedPage
        self.mappings = mappings
        self.widgets = widgets

        // Sanitize minValue, maxValue and step: min <= max, step >= 0
        if type != .colortemperaturepicker {
            self.minValue = minValue ?? 0.0
            self.maxValue = maxValue ?? 100.0
            self.maxValue = max(self.minValue, self.maxValue)
        } else {
            self.minValue = minValue ?? 1000.0
            self.maxValue = maxValue ?? 10000.0
            self.maxValue = max(self.minValue, self.maxValue)
        }
        self.step = abs(self.step)
        self.visibility = visibility ?? true
        self.switchSupport = switchSupport ?? false

        self.forceAsItem = forceAsItem
        self.unit = unit ?? ""
        self.pattern = pattern ?? ""
        self.staticIcon = staticIcon ?? false
        self.labelSource = labelSource
        stateEnumBinding = stateEnum
        self.labelSource = labelSource
        self.releaseOnly = releaseOnly
        self.row = row
        self.column = column
        self.releaseCommand = releaseCommand
        self.command = command
        self.stateless = stateless
        self.staticIcon = staticIcon
        self.unit = unit
        self.pattern = pattern
        self.yAxisDecimalPattern = yAxisDecimalPattern
    }

    convenience init(icon: String, iconColor: String? = nil) {
        self.init(widgetId: "\(UUID())", label: "", icon: icon, type: .unknown, url: nil, period: nil, minValue: nil, maxValue: nil, step: nil, refresh: nil, height: nil, isLeaf: nil, iconColor: iconColor, labelColor: nil, valueColor: nil, service: nil, state: nil, text: nil, legend: nil, inputHint: nil, encoding: nil, item: nil, linkedPage: nil, mappings: [], widgets: [], visibility: nil, switchSupport: nil, forceAsItem: nil, labelSource: .unknown, releaseOnly: nil)
    }
}

//  Recursive parsing of nested widget structure
public extension [OpenHABWidget] {
    mutating func flatten(_ widgets: [Element]) {
        for widget in widgets {
            append(widget)
            if widget.type != .buttongrid {
                flatten(widget.widgets)
            }
        }
    }
}

public extension OpenHABWidget {
    var preferredRowHeight: CGFloat? {
        switch type {
        case .frame:
            label.isEmpty ? 0 : 35.0
        case .image, .chart, .video:
            nil // Automatic sizing
        case .webview, .mapview:
            44.0 * CGFloat(height ?? 8)
        default:
            44.0
        }
    }
}

extension OpenHABWidget {
    convenience init(_ widget: Components.Schemas.WidgetDTO) {
        self.init(
            widgetId: widget.widgetId.orEmpty,
            label: widget.label.orEmpty,
            icon: widget.icon.orEmpty,
            type: OpenHABWidget.WidgetType(rawValue: widget._type ?? "Unknown") ?? .unknown,
            url: widget.url,
            period: widget.period,
            minValue: widget.minValue,
            maxValue: widget.maxValue,
            step: widget.step,
            refresh: widget.refresh.map(Int.init),
            height: widget.height.map(Double.init),
            isLeaf: true,
            iconColor: widget.iconcolor,
            labelColor: widget.labelcolor,
            valueColor: widget.valuecolor,
            service: widget.service,
            state: widget.state,
            text: "",
            legend: widget.legend,
            inputHint: InputHint(rawValue: widget.inputHint ?? "unknown"),
            encoding: widget.encoding,
            item: OpenHABItem(widget.item),
            linkedPage: OpenHABPage(widget.linkedPage),
            mappings: widget.mappings?.compactMap(OpenHABWidgetMapping.init) ?? [],
            widgets: widget.widgets?.compactMap { OpenHABWidget($0) } ?? [],
            visibility: widget.visibility,
            switchSupport: widget.switchSupport,
            forceAsItem: widget.forceAsItem,
            labelSource: OpenHABWidget.LabelSource(rawValue: widget.labelSource ?? "") ?? .unknown,
            releaseOnly: widget.releaseOnly,
            row: widget.row.map { Int($0) },
            column: widget.column.map { Int($0) },
            releaseCommand: widget.releaseCommand,
            command: widget.command,
            stateless: widget.stateless,
            staticIcon: widget.staticIcon,
            unit: widget.unit,
            pattern: widget.pattern,
            yAxisDecimalPattern: widget.yAxisDecimalPattern
        )
    }
}

// Required for behavior of Slider
public extension OpenHABWidget {
    func shouldUseSliderUpdatesDuringMove() -> Bool {
        if let releaseOnly {
            return !releaseOnly
        }

        guard let item else {
            return false
        }

        if item.isOfTypeOrGroupType(.dimmer) ||
            item.isOfTypeOrGroupType(.number) ||
            item.isOfTypeOrGroupType(.color) {
            return true
        }

        if item.isOfTypeOrGroupType(.numberWithDimension) {
            // Allow live updates for percent values, but not for e.g. temperatures
            return stateValueAsNumberState?.unit == "%"
        }

        return false
    }
}
