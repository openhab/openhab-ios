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
import Intents
import OpenHABCore

public enum OpenHABIntentHelper {
    static func resolveHome(home: String?, item: String?) async -> INStringResolutionResult {
        if let home {
            // TODO: fuzzy matching / account for potential renaming?
            // TODO: accept potential mismatches if item name is unique
            let homeInPrefs = Preferences.storedHomes.values.map(\.homeName).filter { $0 == home }
            if homeInPrefs.count == 1 {
                return .success(with: home)
            } else if homeInPrefs.count > 1 {
                return .disambiguation(with: homeInPrefs)
            } else {
                return .unsupported() // given home is nowhere to be found
            }
        } else if let item {
            // try to find the home by home-specific item selection
            let allItems = await OpenHABItemCache.instance.getAllCachedItems()
            let intentItems = allItems.map(\.key).filter { uuid in
                allItems[uuid]?.filtered(by: item).isEmpty != true
            }
            let potentialHomeNames = intentItems.map { Preferences.storedHomes[$0]?.homeName }.filter { $0 != nil }.map { $0 ?? "" }
            if potentialHomeNames.count == 1 {
                guard let homeName = Preferences.storedHomes[intentItems[0]]?.homeName else {
                    return .unsupported() // seems like we found an outdated cached item / home
                }
                return .success(with: homeName)
            } else {
                return .disambiguation(with: potentialHomeNames)
            }
        } else {
            return .needsValue()
        }
    }
}
