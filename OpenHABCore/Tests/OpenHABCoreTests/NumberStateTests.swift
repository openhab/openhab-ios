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

@testable import OpenHABCore
import Testing
import UIKit

@Suite("NumberState")
struct NumberStateTests {
    @Test("toString formats with display pattern")
    func toStringFormatting() {
        #expect(NumberState(value: 100.3, format: "%d").toString(locale: nil) == "100")
        #expect(NumberState(value: 100.4, format: "%d").toString(locale: Locale(identifier: "US")) == "100")
        #expect(NumberState(value: 100.4, format: "%.1f").toString(locale: Locale(identifier: "US")) == "100.4")
        #expect(NumberState(value: 100.4, format: "%.1f").toString(locale: Locale(identifier: "de")) == "100,4")
        #expect(NumberState(value: 100.4, unit: "K", format: "%.1f %unit%").toString(locale: Locale(identifier: "US")) == "100.4 K")
        #expect(NumberState(value: 100.4, unit: "", format: "%.1f %unit%").toString(locale: Locale(identifier: "US")) == "100.4 ")
        #expect(NumberState(value: 100.4, unit: "°C", format: nil).toString(locale: Locale(identifier: "US")) == "100.4 °C")
        #expect(NumberState(value: 100.4, unit: nil, format: nil).toString(locale: Locale(identifier: "US")) == "100.4")
        #expect(NumberState(value: 100.4, unit: "°C", format: "%.1f %unit%").toString(locale: Locale(identifier: "de")) == "100,4 °C")
        #expect(NumberState(value: 100.4, format: "%1$.1f").toString(locale: Locale(identifier: "US")) == "100.4")
        #expect(NumberState(value: 100.4, format: "%1$s").toString(locale: Locale(identifier: "US")) == "100.4")
        #expect(NumberState(value: 100.4, unit: "°C", format: "%,.1f %unit%").toString(locale: Locale(identifier: "de")) == "100.4 °C")
        #expect(NumberState(value: 100.4, unit: "°C", format: "%1$.1f %2$s").toString(locale: Locale(identifier: "de")) == "100.4 °C")
        #expect(NumberState(value: 100.4, unit: "°C", format: "%.1f / %.1f %unit%").toString(locale: Locale(identifier: "de")) == "100.4 °C")
    }

    @Test("commandString preserves fractional values but strips .0 from whole numbers")
    func commandString() {
        // Fractional values must not be truncated by display format
        #expect(NumberState(value: 30.3, format: "%d").commandString == "30.3")
        #expect(NumberState(value: 30.3, unit: "°C", format: "%d %unit%").commandString == "30.3 °C")
        #expect(NumberState(value: 30.3, unit: "°C", format: "%.1f %unit%").commandString == "30.3 °C")
        #expect(NumberState(value: 30.3, unit: nil, format: "%d").commandString == "30.3")
        #expect(NumberState(value: 30.3, unit: "", format: "%d").commandString == "30.3")
        // Whole numbers must be sent without decimal suffix so HTTP binding %2$s passes clean values
        #expect(NumberState(value: 30.0, format: "%d").commandString == "30")
        #expect(NumberState(value: 36.0, format: "%d").commandString == "36")
        #expect(NumberState(value: 100.0, unit: "°C", format: "%d %unit%").commandString == "100 °C")
    }

    @Test("setpoint formatter prefers server label when idle")
    func setpointFormatterPrefersServerLabel() {
        #expect(
            SetpointDisplayFormatter.text(
                labelValue: "21.0 °C",
                localValue: nil,
                serverValue: 21.0,
                minValue: 16.0,
                step: 0.5,
                unit: "°C",
                numberPattern: "%.1f %unit%",
                locale: Locale(identifier: "de")
            ) == "21.0 °C"
        )
    }

    @Test("setpoint formatter formats local override with provided locale")
    func setpointFormatterFormatsLocalOverride() {
        #expect(
            SetpointDisplayFormatter.text(
                labelValue: "21.0 °C",
                localValue: 21.5,
                serverValue: 21.0,
                minValue: 16.0,
                step: 0.5,
                unit: "°C",
                numberPattern: "%.1f %unit%",
                locale: Locale(identifier: "en_US")
            ) == "21.5 °C"
        )
        #expect(
            SetpointDisplayFormatter.text(
                labelValue: "21.0 °C",
                localValue: 21.5,
                serverValue: 21.0,
                minValue: 16.0,
                step: 0.5,
                unit: "°C",
                numberPattern: "%.1f %unit%",
                locale: Locale(identifier: "de")
            ) == "21,5 °C"
        )
    }

    @Test("setpoint formatter falls back without number pattern")
    func setpointFormatterFallsBackWithoutPattern() {
        #expect(
            SetpointDisplayFormatter.text(
                labelValue: nil,
                localValue: 21.5,
                serverValue: 21.0,
                minValue: 16.0,
                step: 0.5,
                unit: "°C",
                numberPattern: nil,
                locale: Locale(identifier: "de")
            ) == "21.5 °C"
        )
        #expect(
            SetpointDisplayFormatter.text(
                labelValue: nil,
                localValue: 21.5,
                serverValue: 21.0,
                minValue: 16.0,
                step: 0.5,
                unit: nil,
                numberPattern: "",
                locale: Locale(identifier: "de")
            ) == "21.5"
        )
    }

    @Test("setpoint formatter falls back to min value for non-finite input")
    func setpointFormatterUsesMinValueForNonFiniteInput() {
        #expect(
            SetpointDisplayFormatter.text(
                labelValue: nil,
                localValue: .nan,
                serverValue: 21.0,
                minValue: 16.0,
                step: 0.5,
                unit: "°C",
                numberPattern: nil,
                locale: SetpointDisplayFormatter.dotDecimalLocale
            ) == "16.0 °C"
        )
        #expect(
            SetpointDisplayFormatter.text(
                labelValue: nil,
                localValue: nil,
                serverValue: .infinity,
                minValue: 16.0,
                step: 0.5,
                unit: "°C",
                numberPattern: nil,
                locale: SetpointDisplayFormatter.dotDecimalLocale
            ) == "16.0 °C"
        )
    }

    @Test("setpoint dot-decimal locale uses dot separator")
    func dotDecimalLocaleUsesDotSeparator() {
        #expect(
            SetpointDisplayFormatter.text(
                labelValue: nil,
                localValue: 21.5,
                serverValue: 21.0,
                minValue: 16.0,
                step: 0.5,
                unit: "°C",
                numberPattern: "%.1f %unit%",
                locale: SetpointDisplayFormatter.dotDecimalLocale
            ) == "21.5 °C"
        )
    }

    @Test("toItemType parses item type strings")
    func toItemType() {
        #expect("NumberItem".toItemType() == OpenHABItem.ItemType.number)
        #expect("Number:Temperature".toItemType() == OpenHABItem.ItemType.numberWithDimension)
        #expect("String".toItemType() == OpenHABItem.ItemType.stringItem)
        #expect("blabla".toItemType() == nil)
    }

    @Test("toWidgetType parses widget type strings")
    func toWidgetType() {
        #expect("Colorpicker".toWidgetType() == OpenHABWidget.WidgetType.colorpicker)
        #expect("colorpicker".toWidgetType() == OpenHABWidget.WidgetType.unknown)
    }

    @Test("parseAs conversions")
    func parseAs() throws {
        #expect("ON".parseAsBool() == true)
        #expect("4,3,1".parseAsBrightness() == 1)
        #expect("4,31".parseAsBrightness() == nil)
        #expect("4,3,0".parseAsBool() == false)
        #expect("4,3,1".parseAsBool() == true)
        #expect("1".parseAsBool() == true)
        #expect("0".parseAsBool() == false)
        #expect("10.1233424".parseAsBool() == true)
        #expect("ON".parseAsNumber() == NumberState(value: 100.0))
        #expect("OFF".parseAsNumber() == NumberState(value: 0.0))
        #expect("24.4 °F".parseAsNumber() == NumberState(value: 24.4, unit: "°F", format: nil))
        #expect("24.4 °F".parseAsNumber(format: "%.f") == NumberState(value: 24.4, unit: "°F", format: "%.f"))

        let col1 = "Uninitialized".parseAsUIColor()
        let col2 = UIColor(hue: 0, saturation: 0, brightness: 0, alpha: 1.0)
        let unwrappedCol1 = try #require(col1)
        #expect(unwrappedCol1.equals(col2))
        #expect("360,100,100".parseAsUIColor() == UIColor(
            hue: CGFloat(state: "360", divisor: 360),
            saturation: CGFloat(state: "100", divisor: 100),
            brightness: CGFloat(state: "100", divisor: 100),
            alpha: 1.0
        ))
    }
}

private extension UIColor {
    func equals(_ rhs: UIColor) -> Bool {
        var lhsR: CGFloat = 0
        var lhsG: CGFloat = 0
        var lhsB: CGFloat = 0
        var lhsA: CGFloat = 0
        getRed(&lhsR, green: &lhsG, blue: &lhsB, alpha: &lhsA)

        var rhsR: CGFloat = 0
        var rhsG: CGFloat = 0
        var rhsB: CGFloat = 0
        var rhsA: CGFloat = 0
        rhs.getRed(&rhsR, green: &rhsG, blue: &rhsB, alpha: &rhsA)

        return lhsR == rhsR &&
            lhsG == rhsG &&
            lhsB == rhsB &&
            lhsA == rhsA
    }
}
