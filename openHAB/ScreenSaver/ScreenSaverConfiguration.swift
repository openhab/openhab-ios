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
    /// Time (in seconds) after the last user interaction before the screen
    /// saver is displayed.
    var idleInterval: TimeInterval = 15 // 2 minutes

    /// How often (in seconds) the time / date label should move to another
    /// random location.
    var movementInterval: TimeInterval = 8

    var showsTime = true

    var showsDate = true

    var showsSeconds = false

    var uses24HourTime = false

    var isEnabled = false

    /// When `true` the screen brightness will be automatically reduced when
    /// the screen saver becomes active.
    var enablesAutoDimming = true

    /// Relative offset that will be added to the current screen brightness when
    /// the screen saver is shown.  Negative values dim the screen, positive
    /// values brighten it.
    var dimmingOffset: CGFloat = -0.4

    /// Font name that will be used for both the time and date.
    /// If `nil` the system  font is used for the time/date
    var fontName: String?

    /// The size of the time (clock) text expressed as a fraction of the
    /// shorter screen edge (so a percentage value)
    var timeFontSizeRatio: CGFloat = 0.2

    /// The size of the date text expressed relative to the computed time font
    /// size (percentage value compared to the clock)
    var dateFontRelativeSize: CGFloat = 0.4

    /// Duration in seconds for the fade in and fade out animation
    var fadeDuration: TimeInterval = 2.0
}
