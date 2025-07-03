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

import Foundation

public struct SetPointService {
    public init() {}

    /// Calculates a new value for a setpoint
    /// - Parameters:
    ///   - currentValue: The current value of the setpoint
    ///   - step: The step to increase/decrease by
    ///   - minValue: The minimum allowed value
    ///   - maxValue: The maximum allowed value
    ///   - isDecreasing: Whether to decrease (true) or increase (false) the value
    /// - Returns: The new value, clamped to the min/max range
    public func calculateNewValue(currentValue: Double,
                                  step: Double,
                                  minValue: Double,
                                  maxValue: Double,
                                  isDecreasing: Bool) -> Double {
        let newValue = isDecreasing ? currentValue - step : currentValue + step
        return newValue.clamped(to: minValue ... maxValue)
    }
}
