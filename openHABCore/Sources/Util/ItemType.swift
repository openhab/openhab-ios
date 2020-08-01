// Copyright (c) 2010-2020 Contributors to the openHAB project
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

// swiftlint:disable file_types_order
public enum ItemType: String {
    case color = "Color"
    case contact = "Contact"
    case dateTime = "DateTime"
    case dimmer = "Dimmer"
    case group = "Group"
    case image = "Image"
    case location = "Location"
    case number = "Number"
    case numberWithDimension = "NumberWithDimension"
    case player = "Player"
    case rollershutter = "Rollershutter"
    case stringItem = "String"
    case switchItem = "Switch"
}

extension ItemType: Decodable {}

public enum WidgetType: String {
    case chart = "Chart"
    case colorpicker = "Colorpicker"
    case defaultWidget = "Default"
    case frame = "Frame"
    case group = "Group"
    case image = "Image"
    case mapview = "Mapview"
    case selection = "Selection"
    case setpoint = "Setpoint"
    case slider = "Slider"
    case switchWidget = "Switch"
    case text = "Text"
    case video = "Video"
    case webview = "Webview"
    case unknown = "Unknown"
}

extension WidgetType: Decodable {}

// Graciously handling of unknown enum types: https://www.latenightswift.com/2019/02/04/unknown-enum-cases/
protocol UnknownCaseRepresentable: RawRepresentable, CaseIterable where RawValue: Equatable {
    static var unknownCase: Self { get }
}

extension UnknownCaseRepresentable {
    public init(rawValue: RawValue) {
        let value = Self.allCases.first { $0.rawValue == rawValue }
        self = value ?? Self.unknownCase
    }
}

extension WidgetType: UnknownCaseRepresentable {
    static var unknownCase: WidgetType = .unknown
}
