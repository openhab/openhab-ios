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
@testable import openHAB
import OpenHABCore
import Testing

// MARK: - Test Helpers

private func makeItem(name: String = "TestItem", type: String, label: String = "Test Item") -> OpenHABItem {
    OpenHABItem(
        name: name,
        type: type,
        state: nil,
        link: "",
        label: label,
        groupType: nil,
        stateDescription: nil,
        commandDescription: nil,
        members: [],
        category: nil,
        options: nil
    )
}

// MARK: - Color Value Validation

@Suite("SetColorValueIntent validation")
struct SetColorValueIntentTests {
    let homeId = UUID()

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    private func makeIntent(home: Home? = nil, value: String = "240,100,100") -> SetColorValueIntent {
        let defaultHome = Home(id: homeId.uuidString, displayString: "Test Home")
        let entity = ColorItemEntity(makeItem(type: "Color", label: "Color Light"), homeId: homeId)
        let i = SetColorValueIntent()
        i.home = home ?? defaultHome
        i.itemEntity = entity
        i.value = value
        return i
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func homeMismatchThrowsItemNotInHome() async {
        let wrongHome = Home(id: UUID().uuidString, displayString: "Wrong Home")
        await #expect(throws: ColorValueError.self) {
            try await makeIntent(home: wrongHome).perform()
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func twoComponentsThrowsInvalidValue() async {
        await #expect(throws: ColorValueError.self) {
            try await makeIntent(value: "240,100").perform()
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func hueAbove360ThrowsInvalidValue() async {
        await #expect(throws: ColorValueError.self) {
            try await makeIntent(value: "361,100,100").perform()
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func negativeHueThrowsInvalidValue() async {
        await #expect(throws: ColorValueError.self) {
            try await makeIntent(value: "-1,100,100").perform()
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func saturationAbove100ThrowsInvalidValue() async {
        await #expect(throws: ColorValueError.self) {
            try await makeIntent(value: "240,101,100").perform()
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func brightnessAbove100ThrowsInvalidValue() async {
        await #expect(throws: ColorValueError.self) {
            try await makeIntent(value: "240,100,101").perform()
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func nonNumericComponentThrowsInvalidValue() async {
        await #expect(throws: ColorValueError.self) {
            try await makeIntent(value: "blue,100,100").perform()
        }
    }
}

// MARK: - Dimmer / Roller Range Validation

@Suite("SetDimmerRollerValueIntent validation")
struct SetDimmerRollerValueIntentTests {
    let homeId = UUID()

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    private func makeIntent(home: Home? = nil, value: Int = 50) -> SetDimmerRollerValueIntent {
        let defaultHome = Home(id: homeId.uuidString, displayString: "Test Home")
        let entity = DimmerItemEntity(makeItem(type: "Dimmer", label: "Dimmer Light"), homeId: homeId)
        let i = SetDimmerRollerValueIntent()
        i.home = home ?? defaultHome
        i.itemEntity = entity
        i.value = value
        return i
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func homeMismatchThrowsItemNotInHome() async {
        let wrongHome = Home(id: UUID().uuidString, displayString: "Wrong Home")
        await #expect(throws: DimmerRollerValueError.self) {
            try await makeIntent(home: wrongHome).perform()
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func valueAbove100ThrowsInvalidValue() async {
        await #expect(throws: DimmerRollerValueError.self) {
            try await makeIntent(value: 101).perform()
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func valueBelow0ThrowsInvalidValue() async {
        await #expect(throws: DimmerRollerValueError.self) {
            try await makeIntent(value: -1).perform()
        }
    }
}

// MARK: - Location Coordinate Validation

@Suite("SetLocationValueIntent validation")
struct SetLocationValueIntentTests {
    let homeId = UUID()

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    private func makeIntent(home: Home? = nil, latitude: Double = 48.0, longitude: Double = 11.0) -> SetLocationValueIntent {
        let defaultHome = Home(id: homeId.uuidString, displayString: "Test Home")
        let entity = LocationItemEntity(makeItem(type: "Location", label: "My Location"), homeId: homeId)
        let intent = SetLocationValueIntent()
        intent.home = home ?? defaultHome
        intent.itemEntity = entity
        intent.latitude = latitude
        intent.longitude = longitude
        return intent
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func homeMismatchThrowsItemNotInHome() async {
        let wrongHome = Home(id: UUID().uuidString, displayString: "Wrong Home")
        await #expect(throws: LocationValueError.self) {
            try await makeIntent(home: wrongHome).perform()
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func latitudeAbove90ThrowsInvalidLatitude() async {
        await #expect(throws: LocationValueError.self) {
            try await makeIntent(latitude: 90.001).perform()
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func latitudeBelow90ThrowsInvalidLatitude() async {
        await #expect(throws: LocationValueError.self) {
            try await makeIntent(latitude: -90.001).perform()
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func longitudeAbove180ThrowsInvalidLongitude() async {
        await #expect(throws: LocationValueError.self) {
            try await makeIntent(latitude: 0, longitude: 180.001).perform()
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func longitudeBelow180ThrowsInvalidLongitude() async {
        await #expect(throws: LocationValueError.self) {
            try await makeIntent(latitude: 0, longitude: -180.001).perform()
        }
    }
}

// MARK: - Switch Home Membership Validation

@Suite("SetSwitchItemIntent validation")
struct SetSwitchItemIntentTests {
    let homeId = UUID()

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func homeMismatchThrowsItemNotInHome() async {
        let wrongHome = Home(id: UUID().uuidString, displayString: "Wrong Home")
        let entity = SwitchItemEntity(makeItem(type: "Switch", label: "My Switch"), homeId: homeId)
        let intent = SetSwitchItemIntent()
        intent.home = wrongHome
        intent.itemEntity = entity
        intent.action = .on
        await #expect(throws: ControlItemError.self) {
            try await intent.perform()
        }
    }
}

// MARK: - Item Search Ranking

@Suite("Item search ranking")
struct ItemSearchRankingTests {
    @Test func homeNameCanContributeToItemSearch() {
        let officeSensor = makeItem(name: "TemperatureSensorOffice", type: "Number", label: "Office Sensor")

        let ranked = [officeSensor].ranked(searchTerm: "main temp", for: nil) { item in
            ["\(item.name) Main Home", "\(item.label) Main Home"]
        }

        #expect(ranked.map(\.item.name) == ["TemperatureSensorOffice"])
    }
}

// MARK: - Error Descriptions

@Suite("Intent error descriptions")
struct IntentErrorDescriptionTests {
    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func colorItemNotInHomeContainsItemAndHomeName() {
        let error = ColorValueError.itemNotInHome("Color Light", "My Home")
        let str = String(localized: error.localizedStringResource)
        #expect(str.contains("Color Light"))
        #expect(str.contains("My Home"))
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func colorInvalidValueContainsValueAndItemName() {
        let error = ColorValueError.invalidValue("blue,100,100", "Color Light")
        let str = String(localized: error.localizedStringResource)
        #expect(str.contains("blue,100,100"))
        #expect(str.contains("Color Light"))
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func dimmerInvalidValueContainsValueAndItemName() {
        let error = DimmerRollerValueError.invalidValue(150, "My Dimmer")
        let str = String(localized: error.localizedStringResource)
        #expect(str.contains("150"))
        #expect(str.contains("My Dimmer"))
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func locationInvalidLatitudeDescriptionContains90() {
        let error = LocationValueError.invalidLatitude
        let str = String(localized: error.localizedStringResource)
        #expect(str.contains("90"))
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    @Test func locationInvalidLongitudeDescriptionContains180() {
        let error = LocationValueError.invalidLongitude
        let str = String(localized: error.localizedStringResource)
        #expect(str.contains("180"))
    }
}

// MARK: - Home Resolution

@Suite("HomeResolver")
struct HomeResolverTests {
    let homeId = UUID()

    @MainActor @Test func optionalHomeUsesItemHomeId() throws {
        let resolved = try HomeResolver.resolvedHomeId(
            selectedHome: nil,
            itemHomeId: homeId,
            itemLabel: "Test Item",
            mismatchError: ItemStateError.itemNotInHome
        )

        #expect(resolved == homeId)
    }

    @MainActor @Test func selectedHomeMismatchThrows() throws {
        let wrongHome = Home(id: UUID().uuidString, displayString: "Wrong Home")

        #expect(throws: ItemStateError.self) {
            try HomeResolver.resolvedHomeId(
                selectedHome: wrongHome,
                itemHomeId: homeId,
                itemLabel: "Test Item",
                mismatchError: ItemStateError.itemNotInHome
            )
        }
    }

    @MainActor @Test func invalidSelectedHomeIdentifierThrows() throws {
        let invalidHome = Home(id: "not-a-uuid", displayString: "Broken Home")

        #expect(throws: HomeResolutionError.self) {
            try HomeResolver.resolvedHomeId(
                selectedHome: invalidHome,
                itemHomeId: homeId,
                itemLabel: "Test Item",
                mismatchError: ItemStateError.itemNotInHome
            )
        }
    }

    @Test func singleStoredHomeBecomesDefault() async throws {
        let resolved = try await HomeResolver.resolveHomeId(
            selectedHome: nil,
            itemName: "TestItem",
            listStoredHomes: { [homeId] },
            exactMatchedHomes: { [] }
        )

        #expect(resolved == homeId)
    }

    @Test func uniqueExactMatchChoosesHome() async throws {
        let otherHomeId = UUID()

        let resolved = try await HomeResolver.resolveHomeId(
            selectedHome: nil,
            itemName: "TestItem",
            listStoredHomes: { [homeId, otherHomeId] },
            exactMatchedHomes: { [otherHomeId] }
        )

        #expect(resolved == otherHomeId)
    }

    @Test func ambiguousHomesRequireSelection() async {
        let otherHomeId = UUID()

        await #expect(throws: HomeResolutionError.self) {
            try await HomeResolver.resolveHomeId(
                selectedHome: nil,
                itemName: "TestItem",
                listStoredHomes: { [homeId, otherHomeId] },
                exactMatchedHomes: { [homeId, otherHomeId] }
            )
        }
    }
}
