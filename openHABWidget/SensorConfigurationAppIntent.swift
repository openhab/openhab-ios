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

import AppIntents
import Foundation

struct SensorConfigurationAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Sensor Widget Configuration"
    static let description = IntentDescription("Configure which sensor item to display in the widget.")

    @Parameter(title: "Home")
    var home: Home?

    @Parameter(title: "Sensor Item")
    var itemEntity: SensorWidgetItemEntity?
}
