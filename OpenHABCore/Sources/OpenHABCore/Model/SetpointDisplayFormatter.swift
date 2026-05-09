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

public enum SetpointDisplayFormatter {
    // Use a stable dot-decimal locale for platforms that intentionally avoid
    // locale-aware formatting until all number controls are migrated together.
    public static let dotDecimalLocale = Locale(identifier: "en_US_POSIX")

    // swiftlint:disable:next function_parameter_count
    public static func text(labelValue: String?,
                            localValue: Double?,
                            serverValue: Double,
                            minValue: Double,
                            step: Double,
                            unit: String?,
                            numberPattern: String?,
                            locale: Locale) -> String {
        if localValue == nil, let labelValue, !labelValue.isEmpty {
            return labelValue
        }

        let resolvedValue = (localValue ?? serverValue).isFinite ? (localValue ?? serverValue) : minValue

        if let numberPattern, !numberPattern.isEmpty {
            let formatted = NumberState(
                value: resolvedValue,
                unit: unit,
                format: numberPattern
            ).toString(locale: locale)
            if !formatted.isEmpty {
                return formatted
            }
        }

        let fallback = resolvedValue.valueText(step: step)
        if let unit, !unit.isEmpty {
            return "\(fallback) \(unit)"
        }
        return fallback
    }
}
