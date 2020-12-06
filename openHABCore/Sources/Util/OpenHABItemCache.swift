// Copyright (c) 2010-2020 Contributors to the openHAB project
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
import os.log

public class OpenHABItemCache {
    public static let instance = OpenHABItemCache()

    public static let URL_NONE = 0
    public static let URL_LOCAL = 1
    public static let URL_REMOTE = 2
    public static let URL_DEMO = 3

    public var items: [OpenHABItem]?
    public var url = ""
    public var localUrlFailed = false
    public var lastUrlConnected = URL_NONE
    public var lastLoad = Date().timeIntervalSince1970

    public func getItemNames(searchTerm: String?, types: [OpenHABItem.ItemType]?, completion: @escaping ([NSString]) -> Void) {
        var ret = [NSString]()

        guard let items = items else {
            if #available(iOS 12.0, *) {
                reload(searchTerm: searchTerm, types: types, completion: completion)
            } else {
                // Fallback on earlier versions
            }
            return
        }

        ret.append(contentsOf: items.filter { (searchTerm == nil || $0.name.contains(searchTerm.orEmpty)) && (types == nil || ($0.type != nil && types!.contains($0.type!))) }.map { NSString(string: $0.name) })

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
        lastLoad = Date().timeIntervalSince1970

        guard let uurl = getURL() else { return }

        os_log("Loading items from %{PUBLIC}@", log: .default, type: .info, url)

        if NetworkConnection.shared == nil {
            NetworkConnection.initialize(ignoreSSL: Preferences.ignoreSSL, adapter: nil)
        }

        let timeout = lastUrlConnected == OpenHABItemCache.URL_LOCAL ? 5.0 : 10.0

        NetworkConnection.load(from: uurl, timeout: timeout) { response in
            switch response.result {
            case .success:
                if let data = response.result.value {
                    do {
                        try self.decodeItemsData(data)

                        let ret = self.items?.filter { (searchTerm == nil || $0.name.contains(searchTerm.orEmpty)) && (types == nil || ($0.type != nil && types!.contains($0.type!))) }.map(\.name).map { NSString(string: $0) } ?? []

                        completion(ret)
                    } catch {
                        os_log("%{PUBLIC}@ ", log: .default, type: .error, error.localizedDescription)
                    }
                }
            case let .failure(error):
                if self.lastUrlConnected == OpenHABItemCache.URL_LOCAL {
                    self.localUrlFailed = true
                    os_log("%{PUBLIC}@ ", log: .default, type: .info, error.localizedDescription)
                    self.reload(searchTerm: searchTerm, types: types, completion: completion) // try remote

                } else {
                    os_log("%{PUBLIC}@ ", log: .default, type: .error, error.localizedDescription)
                }
            }
        }
    }

    @available(iOS 12.0, *)
    public func reload(name: String, completion: @escaping (OpenHABItem?) -> Void) {
        lastLoad = Date().timeIntervalSince1970

        guard let uurl = getURL() else { return }

        os_log("Loading items from %{PUBLIC}@", log: .default, type: .info, url)

        if NetworkConnection.shared == nil {
            NetworkConnection.initialize(ignoreSSL: Preferences.ignoreSSL, adapter: nil)
        }

        let timeout = lastUrlConnected == OpenHABItemCache.URL_LOCAL ? 5.0 : 10.0

        NetworkConnection.load(from: uurl, timeout: timeout) { response in
            switch response.result {
            case .success:
                if let data = response.result.value {
                    do {
                        try self.decodeItemsData(data)

                        let item = self.getItem(name)

                        completion(item)

                    } catch {
                        os_log("%{PUBLIC}@ ", log: .default, type: .error, error.localizedDescription)
                    }
                }

            case let .failure(error):
                if self.lastUrlConnected == OpenHABItemCache.URL_LOCAL {
                    self.localUrlFailed = true
                    os_log("%{PUBLIC}@ ", log: .default, type: .info, error.localizedDescription)
                    self.reload(name: name, completion: completion) // try remote

                } else {
                    os_log("%{PUBLIC}@ ", log: .default, type: .error, error.localizedDescription)
                }
            }
        }
    }

    func getURL() -> URL? {
        var uurl: URL?

        if Preferences.demomode {
            uurl = Endpoint.items(openHABRootUrl: "http://demo.openhab.org:8080").url
            url = uurl?.absoluteString ?? "unknown"
            lastUrlConnected = OpenHABItemCache.URL_DEMO

        } else {
            if localUrlFailed {
                uurl = Endpoint.items(openHABRootUrl: Preferences.remoteUrl).url
                url = uurl?.absoluteString ?? "unknown"
                lastUrlConnected = OpenHABItemCache.URL_REMOTE

            } else {
                uurl = Endpoint.items(openHABRootUrl: Preferences.localUrl).url
                url = uurl?.absoluteString ?? "unknown"
                lastUrlConnected = OpenHABItemCache.URL_LOCAL
            }
        }

        return uurl
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
