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
import OpenHABCore

/// Shared fixture factory for SwiftUI previews and lightweight rendering tests.
public enum PreviewWidgetFactory {
    public static func slider(label: String,
                              value: Double? = nil,
                              minValue: Double = 0.0,
                              maxValue: Double = 100.0,
                              step: Double = 1.0,
                              icon: String = "slider",
                              switchSupport: Bool = false,
                              pattern: String? = nil) -> OpenHABWidget {
        let widget = makeWidget(
            type: .slider,
            label: label,
            valueText: value.map { String(Int($0)) },
            state: value.map { String($0) } ?? "NULL",
            itemType: "Dimmer",
            icon: icon,
            minValue: minValue,
            maxValue: maxValue,
            step: step,
            switchSupport: switchSupport
        )
        widget.pattern = pattern
        return widget
    }

    public static func switchWidget(label: String,
                                    state: String = "OFF",
                                    icon: String = "switch") -> OpenHABWidget {
        makeWidget(
            type: .switchWidget,
            label: label,
            valueText: state,
            state: state,
            itemType: "Switch",
            icon: icon
        )
    }

    public static func setpoint(label: String,
                                value: Double,
                                minValue: Double = 0.0,
                                maxValue: Double = 100.0,
                                step: Double = 1.0,
                                unit: String? = nil,
                                icon: String = "temperature") -> OpenHABWidget {
        let widget = makeWidget(
            type: .setpoint,
            label: label,
            valueText: String(value),
            state: String(value),
            itemType: "Number",
            icon: icon,
            minValue: minValue,
            maxValue: maxValue,
            step: step
        )
        widget.unit = unit
        return widget
    }

    public static func selection(label: String,
                                 options: [(String, String)],
                                 selectedIndex: Int = 0,
                                 icon: String = "selection") -> OpenHABWidget {
        let mappings = options.map { OpenHABWidgetMapping(command: $0.0, label: $0.1) }
        let selectedCommand = options[safe: selectedIndex]?.0 ?? ""
        let widget = makeWidget(
            type: .selection,
            label: label,
            valueText: options[safe: selectedIndex]?.1,
            state: selectedCommand,
            itemType: "String",
            icon: icon
        )
        widget.mappings = mappings
        return widget
    }

    public static func segmented(label: String,
                                 mappings: [OpenHABWidgetMapping],
                                 selectedState: String? = nil,
                                 icon: String = "switch",
                                 valueText: String? = nil) -> OpenHABWidget {
        let widget = makeWidget(
            type: .switchWidget,
            label: label,
            valueText: valueText,
            state: selectedState ?? mappings.first?.command ?? "",
            itemType: "String",
            icon: icon
        )
        widget.mappings = mappings
        return widget
    }

    public static func rollershutter(label: String,
                                     state: String = "STOP",
                                     icon: String = "rollershutter") -> OpenHABWidget {
        makeWidget(
            type: .switchWidget,
            label: label,
            valueText: state,
            state: state,
            itemType: "Rollershutter",
            icon: icon
        )
    }

    public static func colorpicker(label: String,
                                   state: String = "0,100,100",
                                   icon: String = "colorwheel") -> OpenHABWidget {
        makeWidget(
            type: .colorpicker,
            label: label,
            valueText: nil,
            state: state,
            itemType: "Color",
            icon: icon
        )
    }

    public static func frame(label: String) -> OpenHABWidget {
        makeWidget(
            type: .frame,
            label: label,
            valueText: nil,
            state: "",
            itemType: "Group",
            icon: "frame"
        )
    }

    public static func mapview(label: String,
                               state: String = "0,0",
                               icon: String = "map") -> OpenHABWidget {
        makeWidget(
            type: .mapview,
            label: label,
            valueText: nil,
            state: state,
            itemType: "Location",
            icon: icon
        )
    }

    public static func imageRaw(label: String,
                                base64: String,
                                icon: String = "image") -> OpenHABWidget {
        makeWidget(
            type: .image,
            label: label,
            valueText: nil,
            state: "image/png,\(base64)",
            itemType: "Image",
            icon: icon
        )
    }

    public static func text(label: String,
                            valueText: String? = nil,
                            icon: String = "text") -> OpenHABWidget {
        makeWidget(
            type: .text,
            label: label,
            valueText: valueText,
            state: valueText ?? "",
            itemType: "String",
            icon: icon
        )
    }

    public static func generic(label: String,
                               valueText: String? = nil,
                               icon: String = "item") -> OpenHABWidget {
        makeWidget(
            type: .unknown,
            label: label,
            valueText: valueText,
            state: valueText ?? "",
            itemType: "String",
            icon: icon
        )
    }

    // swiftlint:disable:next function_parameter_count
    private static func makeWidget(type: OpenHABWidget.WidgetType,
                                   label: String,
                                   valueText: String?,
                                   state: String,
                                   itemType: String,
                                   icon: String,
                                   minValue: Double = 0.0,
                                   maxValue: Double = 100.0,
                                   step: Double = 1.0,
                                   switchSupport: Bool = false) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = UUID().uuidString
        widget.type = type
        widget.icon = icon
        widget.minValue = minValue
        widget.maxValue = maxValue
        widget.step = step
        widget.switchSupport = switchSupport

        if let valueText {
            widget.label = "\(label) [\(valueText)]"
        } else {
            widget.label = label
        }

        let item = OpenHABItem(
            name: "Preview_\(label.replacingOccurrences(of: " ", with: "_"))",
            type: itemType,
            state: state,
            link: "",
            label: label,
            groupType: nil,
            stateDescription: nil,
            commandDescription: nil,
            members: [],
            category: nil,
            options: nil
        )
        widget.item = item

        return widget
    }
}
