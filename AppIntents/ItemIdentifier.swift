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
import OpenHABCore

struct ItemIdentifier: Hashable, Codable {
    let homeId: UUID
    let itemName: String
}

extension ItemIdentifier: EntityIdentifierConvertible {
    var entityIdentifierString: String {
        "\(homeId.uuidString):\(itemName)"
    }

    static func entityIdentifier(for entityIdentifierString: String) -> ItemIdentifier? {
        let components = entityIdentifierString.split(separator: ":", maxSplits: 1)
        guard components.count == 2,
              let homeId = UUID(uuidString: String(components[0])) else {
            return nil
        }
        return ItemIdentifier(homeId: homeId, itemName: String(components[1]))
    }
}
