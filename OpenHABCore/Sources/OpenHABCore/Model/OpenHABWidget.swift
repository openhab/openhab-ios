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

public enum SitemapWidgetEventApplicationResult: Equatable, Sendable {
    case applied
    case unchanged
    case notFound
    case requiresPageReload
}

public class OpenHABWidget: NSObject, MKAnnotation, Identifiable, ObservableObject {
    public enum WidgetType: String, Decodable, Sendable {
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
    public var yAxisDecimalPattern: String?

    public var widgetType: WidgetType {
        type
    }

    public var hasLinkedPage: Bool {
        linkedPage != nil
    }

    public var coordinate: CLLocationCoordinate2D {
        item?.stateAsLocation()?.coordinate ?? kCLLocationCoordinate2DInvalid
    }
}

public extension OpenHABWidget {
    /// This is an ugly initializer
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
        self.unit = unit
        self.pattern = pattern
        self.staticIcon = staticIcon
        self.labelSource = labelSource
        self.releaseOnly = releaseOnly
        self.row = row
        self.column = column
        self.releaseCommand = releaseCommand
        self.command = command
        self.stateless = stateless
        self.yAxisDecimalPattern = yAxisDecimalPattern
    }

    convenience init(icon: String, iconColor: String? = nil) {
        // swiftlint:disable:next line_length
        self.init(widgetId: "\(UUID())", label: "", icon: icon, type: .unknown, url: nil, period: nil, minValue: nil, maxValue: nil, step: nil, refresh: nil, height: nil, isLeaf: nil, iconColor: iconColor, labelColor: nil, valueColor: nil, service: nil, state: nil, text: nil, legend: nil, inputHint: nil, encoding: nil, item: nil, linkedPage: nil, mappings: [], widgets: [], visibility: nil, switchSupport: nil, forceAsItem: nil, labelSource: .unknown, releaseOnly: nil)
    }
}

/// Associated-object key for parentWidgetId — avoids changing OpenHABWidget's stored-property
/// layout, which would corrupt Combine's @Published field scan under concurrent test execution.
private nonisolated(unsafe) var parentWidgetIdKey: UInt8 = 0

public extension OpenHABWidget {
    var parentWidgetId: String? {
        get { objc_getAssociatedObject(self, &parentWidgetIdKey) as? String }
        set { objc_setAssociatedObject(self, &parentWidgetIdKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC) }
    }
}

///  Recursive parsing of nested widget structure
public extension [OpenHABWidget] {
    mutating func flatten(_ widgets: [Element], parentWidgetId: String? = nil) {
        for widget in widgets {
            widget.parentWidgetId = parentWidgetId
            append(widget)
            if widget.type != .buttongrid {
                flatten(widget.widgets, parentWidgetId: widget.widgetId)
            }
        }
    }
}

public extension OpenHABWidget {
    @discardableResult
    func apply(event: OpenHABSitemapWidgetEvent) -> SitemapWidgetEventApplicationResult {
        guard let eventWidgetId = event.widgetId else { return .notFound }

        if widgetId == eventWidgetId {
            guard event.descriptionChanged != true else {
                return .requiresPageReload
            }
            // reloadIcon arrives on virtually every SSE event but carries no
            // displayable payload of its own — skip the rebuild if nothing else changed.
            guard event.label != nil || event.icon != nil || event.state != nil
                || event.enrichedItem != nil || event.labelcolor != nil
                || event.valuecolor != nil || event.iconcolor != nil
                || event.visibility != nil || event.labelSource != nil
            else { return .unchanged }
            if let label = event.label { self.label = label }
            if let icon = event.icon { self.icon = icon }
            if let labelcolor = event.labelcolor { self.labelcolor = labelcolor }
            if let valuecolor = event.valuecolor { self.valuecolor = valuecolor }
            if let iconcolor = event.iconcolor { iconColor = iconcolor }
            if let visibility = event.visibility { self.visibility = visibility }
            if let state = event.state {
                self.state = state
            } else if let itemState = event.enrichedItem?.state {
                state = itemState
            }
            if let item = event.enrichedItem { self.item = item }
            if let labelSource = event.labelSource {
                self.labelSource = OpenHABWidget.LabelSource(rawValue: labelSource) ?? .unknown
            }
            return .applied
        }

        for widget in widgets {
            let result = widget.apply(event: event)
            if result != .notFound {
                return result
            }
        }
        return .notFound
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

extension OpenHABWidget: WidgetRendering {}
