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
import OpenHABCore

struct ItemIdentifier: Codable {
    private static let currentFormatPrefix = "v2"

    let homeId: UUID?
    let itemName: String
    let homeIdentifier: String?

    init(homeId: UUID, itemName: String, homeIdentifier: String? = nil) {
        self.homeId = homeId
        self.itemName = itemName
        self.homeIdentifier = homeIdentifier
    }

    init(unresolvedHomeIdentifier homeIdentifier: String, itemName: String) {
        homeId = nil
        self.itemName = itemName
        self.homeIdentifier = homeIdentifier
    }
}

/// homeId is a device-local UUID used only for cache lookups and network-tracker resolution.
/// For v2 identifiers (homeIdentifier != nil), entity identity is homeIdentifier + itemName so the
/// App Intents framework can match shortcuts across devices even when the embedded UUID differs.
/// For legacy identifiers (homeIdentifier == nil), homeId is the only home discriminator available,
/// so it is included in equality — without it, same-named items from different homes would collide.
extension ItemIdentifier: Equatable {
    static func == (lhs: ItemIdentifier, rhs: ItemIdentifier) -> Bool {
        guard lhs.homeIdentifier == nil, rhs.homeIdentifier == nil else {
            return lhs.homeIdentifier == rhs.homeIdentifier && lhs.itemName == rhs.itemName
        }
        return lhs.homeId == rhs.homeId && lhs.itemName == rhs.itemName
    }
}

extension ItemIdentifier: Hashable {
    func hash(into hasher: inout Hasher) {
        if let homeIdentifier {
            hasher.combine(homeIdentifier)
        } else {
            hasher.combine(homeId)
        }
        hasher.combine(itemName)
    }
}

extension ItemIdentifier: EntityIdentifierConvertible {
    var entityIdentifierString: String {
        if let homeIdentifier {
            return [
                Self.currentFormatPrefix,
                Self.encoded(homeIdentifier),
                Self.encoded(itemName)
            ].joined(separator: ":")
        }

        guard let homeId else {
            // Both homeId and homeIdentifier are nil — produce a 3-component v2 string with an
            // empty home segment so currentFormatIdentifier(for:) can round-trip it. Omitting the
            // home segment produces a 2-component string that currentFormatIdentifier rejects.
            return [
                Self.currentFormatPrefix,
                Self.encoded(""),
                Self.encoded(itemName)
            ].joined(separator: ":")
        }
        return "\(homeId.uuidString):\(itemName)"
    }

    static func entityIdentifier(for entityIdentifierString: String) -> ItemIdentifier? {
        if let currentFormatIdentifier = currentFormatIdentifier(for: entityIdentifierString) {
            return currentFormatIdentifier
        }

        let components = entityIdentifierString.split(separator: ":", maxSplits: 1)
        guard components.count == 2,
              let homeId = UUID(uuidString: String(components[0])) else {
            return nil
        }
        return ItemIdentifier(homeId: homeId, itemName: String(components[1]))
    }

    private static func currentFormatIdentifier(for entityIdentifierString: String) -> ItemIdentifier? {
        let components = entityIdentifierString.split(separator: ":", maxSplits: 2).map(String.init)
        guard components.count == 3,
              components[0] == currentFormatPrefix,
              let homeIdentifier = decoded(components[1]),
              let itemName = decoded(components[2]) else {
            return nil
        }

        if let homeId = Home.localIdentifierComponent(of: homeIdentifier) {
            return ItemIdentifier(homeId: homeId, itemName: itemName, homeIdentifier: homeIdentifier)
        }
        return ItemIdentifier(unresolvedHomeIdentifier: homeIdentifier, itemName: itemName)
    }

    private static func encoded(_ value: String) -> String {
        Data(value.utf8).base64EncodedString()
    }

    private static func decoded(_ value: String) -> String? {
        guard let data = Data(base64Encoded: value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
