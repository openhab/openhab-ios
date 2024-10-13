// Copyright (c) 2010-2024 Contributors to the openHAB project
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

public class OpenHABItemCache {
    public static let instance = OpenHABItemCache()
    public var items: [OpenHABItem]?
    var cancellables = Set<AnyCancellable>()
    var timeout: Double = 20
    var lastLoad = Date().timeIntervalSince1970

    private init() {
        if NetworkConnection.shared == nil {
            NetworkConnection.initialize(ignoreSSL: Preferences.ignoreSSL, interceptor: nil)
        }
        let connection1 = ConnectionConfiguration(
            url: Preferences.localUrl,
            priority: 0
        )
        let connection2 = ConnectionConfiguration(
            url: Preferences.remoteUrl,
            priority: 1
        )
        NetworkTracker.shared.startTracking(connectionConfigurations: [connection1, connection2], username: Preferences.username, password: Preferences.password, alwaysSendBasicAuth: Preferences.alwaysSendCreds)
    }

    public func getItemNames(searchTerm: String?, types: [OpenHABItem.ItemType]?, completion: @escaping ([NSString]) -> Void) {
        var ret = [NSString]()

        guard let items else {
            reload(searchTerm: searchTerm, types: types, completion: completion)
            return
        }

        ret.append(contentsOf: items.filter { (searchTerm == nil || $0.name.contains(searchTerm.orEmpty)) && (types == nil || ($0.type != nil && types!.contains($0.type!))) }.sorted(by: \.name).map { NSString(string: $0.name) })

        completion(ret)
    }

    @available(iOS 12.0, *)
    public func getItem(name: String, completion: @escaping (OpenHABItem?) -> Void) {
        let now = Date().timeIntervalSince1970

        if items == nil || (now - lastLoad) > 10 { // More than 10 seconds - reload
            reload(name: name, completion: completion)
            return
        }
        completion(getItem(name))
    }

    func getItem(_ name: String) -> OpenHABItem? {
        items?.first { $0.name == name }
    }

    public func sendCommand(_ item: OpenHABItem, commandToSend command: String) {
        let commandOperation = NetworkConnection.sendCommand(item: item, commandToSend: command)
        commandOperation?.resume()
    }

    public func sendState(_ item: OpenHABItem, stateToSend command: String) {
        let commandOperation = NetworkConnection.sendState(item: item, stateToSend: command)
        commandOperation?.resume()
    }

    @available(iOS 12.0, *)
    public func reload(searchTerm: String?, types: [OpenHABItem.ItemType]?, completion: @escaping ([NSString]) -> Void) {
        NetworkTracker.shared.waitForActiveConnection { activeConnection in
            if let urlString = activeConnection?.configuration.url, let url = Endpoint.items(openHABRootUrl: urlString).url {
                os_log("OpenHABItemCache Loading items from %{PUBLIC}@", log: .default, type: .info, urlString)
                self.lastLoad = Date().timeIntervalSince1970
                NetworkConnection.load(from: url, timeout: self.timeout) { response in
                    switch response.result {
                    case let .success(data):
                        do {
                            try self.decodeItemsData(data)
                            let ret = self.items?.filter { (searchTerm == nil || $0.name.contains(searchTerm.orEmpty)) && (types == nil || ($0.type != nil && types!.contains($0.type!))) }.sorted(by: \.name).map { NSString(string: $0.name) } ?? []
                            completion(ret)
                        } catch {
                            print(error)
                            os_log("OpenHABItemCache %{PUBLIC}@ ", log: .default, type: .error, error.localizedDescription)
                        }
                    case let .failure(error):
                        os_log("OpenHABItemCache %{PUBLIC}@ ", log: .default, type: .error, error.localizedDescription)
                    }
                }
            }
        }
        .store(in: &cancellables)
    }

    @available(iOS 12.0, *)
    public func reload(name: String, completion: @escaping (OpenHABItem?) -> Void) {
        NetworkTracker.shared.waitForActiveConnection { activeConnection in
            if let urlString = activeConnection?.configuration.url, let url = Endpoint.items(openHABRootUrl: urlString).url {
                os_log("OpenHABItemCache Loading items from %{PUBLIC}@", log: .default, type: .info, urlString)
                self.lastLoad = Date().timeIntervalSince1970
                NetworkConnection.load(from: url, timeout: self.timeout) { response in
                    switch response.result {
                    case let .success(data):
                        do {
                            try self.decodeItemsData(data)
                            let item = self.getItem(name)
                            completion(item)
                        } catch {
                            os_log("OpenHABItemCache %{PUBLIC}@ ", log: .default, type: .error, error.localizedDescription)
                        }
                    case let .failure(error):
                        print(error)
                        os_log("OpenHABItemCache %{PUBLIC}@ ", log: .default, type: .error, error.localizedDescription)
                    }
                }
            }
        }
        .store(in: &cancellables)
    }

    private func decodeItemsData(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)
        let codingDatas = try data.decoded(as: [OpenHABItem.CodingData].self, using: decoder)
        items = [OpenHABItem]()
        for codingDatum in codingDatas where codingDatum.openHABItem.type != OpenHABItem.ItemType.group {
            self.items?.append(codingDatum.openHABItem)
        }
        os_log("Loaded items to cache: %{PUBLIC}d", log: .default, type: .info, items?.count ?? 0)
    }
}
