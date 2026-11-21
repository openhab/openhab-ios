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

struct OpenHABItemCacheSearchTests {
    @Test
    func exactNameMatchRanksAheadOfPartialLabelMatch() {
        let exactName = makeItem(name: "Light", label: "Ceiling")
        let partialLabel = makeItem(name: "KitchenSwitch", label: "Kitchen Light")

        let ranked = [partialLabel, exactName].ranked(searchTerm: "Light", for: nil)

        #expect(ranked.map(\.item.name) == ["Light", "KitchenSwitch"])
    }

    @Test
    func multiSubstringSearchMatchesAcrossWords() {
        let kitchenSwitch = makeItem(name: "KitchenSwitch", label: "Kitchen Main Switch")
        let bedroomLight = makeItem(name: "BedroomLight", label: "Bedroom Ceiling Light")

        let ranked = [bedroomLight, kitchenSwitch].ranked(searchTerm: "kit swi", for: nil)

        #expect(ranked.map(\.item.name) == ["KitchenSwitch"])
    }

    @Test
    func rankedSearchHonorsTypeFilter() {
        let switchItem = makeItem(name: "KitchenSwitch", label: "Kitchen Switch", type: "Switch")
        let numberItem = makeItem(name: "KitchenTemperature", label: "Kitchen Temperature", type: "Number")

        let ranked = [switchItem, numberItem].ranked(searchTerm: "kitchen", for: [.switchItem])

        #expect(ranked.map(\.item.name) == ["KitchenSwitch"])
    }

    @Test
    func rankedSearchMatchesAdditionalCandidates() {
        let officeSensor = makeItem(name: "TemperatureSensorOffice", label: "Office Sensor", type: "Number")

        let ranked = [officeSensor].ranked(searchTerm: "main temp", for: nil) { item in
            ["\(item.name) Main Home", "\(item.label) Main Home"]
        }

        #expect(ranked.map(\.item.name) == ["TemperatureSensorOffice"])
    }

    private func makeItem(name: String, label: String, type: String = "Switch") -> OpenHABItem {
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
}
