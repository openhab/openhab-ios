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

import OpenHABCore
import SwiftUI

public extension Color {
    init(fromString string: String) {
        self.init(UIColor(fromString: string))
    }

    init(hex: String) {
        self.init(UIColor(hex: hex))
    }
}

public typealias Kelvin = Double

public extension Color {
    init(temperature: Kelvin) {
        let components = componentsForColorTemperature(temperature: temperature)
        self.init(red: components.r, green: components.g, blue: components.b)
    }

    func hexString() -> String {
        let components = cgColor?.components
        let r: CGFloat = components?[0] ?? 0.0
        let g: CGFloat = components?[1] ?? 0.0
        let b: CGFloat = components?[2] ?? 0.0

        return String(format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
    }
}

// For algorithm see https://web.archive.org/web/20151024031939/http://www.zombieprototypes.com/?p=210
// Algorithm see  http://www.tannerhelland.com/4435/convert-temperature-rgb-algorithm-code/
// swiftlint:disable:next large_tuple
func componentsForColorTemperature(temperature: Kelvin) -> (r: Double, g: Double, b: Double) {
    let k = temperature / 100
    let r = (k <= 66 ? 255 : (329.698727446 * pow(k - 60, -0.1332047592))).clamped(to: 0 ... 255.0) / 255
    let g = (k <= 66 ? (99.4708025861 * log(k) - 161.1195681661) : 288.1221695283 * pow(k - 60, -0.0755148492)).clamped(to: 0 ... 255.0) / 255
    let b = (k >= 66 ? 255 : (k <= 19 ? 0 : 138.5177312231 * log(k - 10) - 305.0447927307)).clamped(to: 0 ... 255.0) / 255
    return (r: r, g: g, b: b)
}
