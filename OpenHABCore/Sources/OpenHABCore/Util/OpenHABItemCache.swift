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

import Combine
import Foundation
import os.log

public protocol ItemCacheProtocol {
    func getItem(name: String) async -> OpenHABItem?
    func sendCommand(_ item: OpenHABItem, commandToSend: String) async
    func getItemNames(searchTerm: String?, types: [OpenHABItem.ItemType]?) async -> [String]
}

public actor OpenHABItemCache {
    public static let instance = OpenHABItemCache()

    public var items: [OpenHABItem]?
    var cancellables = Set<AnyCancellable>()
    var timeout: Double = 20
    var lastLoad = Date().timeIntervalSince1970

    private let logger = Logger(subsystem: "org.openhab.app.watchkitapp", category: "OpenHABItemCache")

    private init() {
        let connection1 = Preferences.localConnectionConfig
        let connection2 = Preferences.remoteConnectionConfig

        NetworkTracker.shared.startTracking(connectionConfigurations: [connection1, connection2])
    }

    private init(connections: [ConnectionConfiguration]) {
        NetworkTracker.shared.startTracking(connectionConfigurations: connections)
    }

    public func getItemNames(searchTerm: String?, types: [OpenHABItem.ItemType]?) async -> [String] {
        guard let items else {
            return []
        }

        return items
            .filter {
                (searchTerm == nil || $0.name.contains(searchTerm.orEmpty)) &&
                    (types == nil || ($0.type != nil && types!.contains($0.type!)))
            }
            .sorted(by: \.name)
            .map(\.name)
    }

    public func getItem(name: String) async -> OpenHABItem? {
        let now = Date().timeIntervalSince1970

        if items == nil || (now - lastLoad) > 10 {
            return await reload(name: name)
        }
        return getItem(name)
    }

    func getItem(_ name: String) -> OpenHABItem? {
        items?.first { $0.name == name }
    }

    public func sendCommand(_ item: OpenHABItem, commandToSend command: String) async {
        do {
            try await NetworkTracker.shared.send(to: item, command: command)
        } catch {
            logger.info("Could not send command: \(error.localizedDescription)")
        }
    }

    public func sendState(_ item: OpenHABItem, stateToSend state: String) async {
        do {
            try await NetworkTracker.shared.updateState(for: item, state: state)
        } catch {
            logger.info("Could not send state: \(error.localizedDescription)")
        }
    }

    public func reload(searchTerm: String?, types: [OpenHABItem.ItemType]?) async -> [String] {
        os_log("OpenHABItemCache Loading items ")
        lastLoad = Date().timeIntervalSince1970

        do {
            items = try await NetworkTracker.shared.getItems()
            os_log("Loaded items to cache: %{PUBLIC}d", log: .default, type: .info, self.items?.count ?? 0)
            return await getItemNames(searchTerm: searchTerm, types: types)
        } catch {
            os_log("OpenHABItemCache %{PUBLIC}@ ", log: .default, type: .error, error.localizedDescription)
            return []
        }
    }

    public func reload(name: String) async -> OpenHABItem? {
        do {
            items = try await NetworkTracker.shared.getItems()
            os_log("Loaded items to cache: %{PUBLIC}d", log: .default, type: .info, self.items?.count ?? 0)
            return items?.first { $0.name == name }
        } catch {
            os_log("OpenHABItemCache %{PUBLIC}@ ", log: .default, type: .error, error.localizedDescription)
            return nil
        }
    }
}

extension OpenHABItemCache: ItemCacheProtocol {}
