// Copyright (c) 2010-2025 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import CoreGraphics
import Foundation

struct ScreenSaverConfiguration {
    var idleInterval: TimeInterval = 15

    var movementInterval: TimeInterval = 8

    var showsTime = true

    var showsDate = true

    var showsSeconds = false

    var uses24HourTime = false

    var isEnabled = false

    var enablesAutoDimming = true

    var dimLevel: CGFloat = 0.3

    var restoresBrightness = true

    var wakeBrightnessLevel: CGFloat = 1.0

    /// If `nil` the system  font is used for the time/date
    var fontName: String?

    var timeFontSizeRatio: CGFloat = 0.2

    /// The size of the date text, percentage value compared to the clock
    var dateFontRelativeSize: CGFloat = 0.4

    var fadeDuration: TimeInterval = 2.0
}
