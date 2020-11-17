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

    static let MODE_GET_ITEM = 0
    static let MODE_FILTER_ITEMS = 1

    public var items: [OpenHABItem]?
    public var url = ""
    public var lastLoad = NSDate().timeIntervalSince1970

    public func getItemNames(searchTerm: String?, types: [String]?) -> [NSString] {
        var ret = [NSString]()

        if items == nil {
            reload()
            return ret
        }

        for item in items! where (searchTerm == nil || item.name.contains(searchTerm ?? "")) && (types == nil || types!.contains(item.type?.rawValue ?? "unknownsksskl")) {
            ret.append(NSString(string: item.name))
        }

        return ret
    }

    @available(iOS 12.0, *)
    public func getItem(name: String, completion: @escaping (OpenHABItem) -> Void) {
        let now = NSDate().timeIntervalSince1970

        if items == nil || (now - lastLoad) > 5 {
            reload(mode: OpenHABItemCache.MODE_GET_ITEM, name: name, completion: completion)
            return
        }

        for item in items! where item.name == name {
            completion(item)

            return
        }
    }

    public func getItem(_ name: String) -> OpenHABItem? {
        if items == nil {
            return nil
        }

        for item in items! where item.name == name {
            return item
        }

        return nil
    }

    public func sendCommand(_ item: OpenHABItem, commandToSend command: String) {
        let commandOperation = NetworkConnection.sendCommand(item: item, commandToSend: command)
        commandOperation?.resume()
    }

    @available(iOS 12.0, *)
    public func reload(mode: Int, name: String?, completion: @escaping (OpenHABItem) -> Void) {
        lastLoad = NSDate().timeIntervalSince1970

        print("ignoreSSL: \(Preferences.ignoreSSL)")
        print("localUrl: " + Preferences.localUrl)
        print("remoteUrl: " + Preferences.remoteUrl)
        print("username: " + Preferences.username)
        print("password: " + Preferences.password)

        var uurl = URL(string: url)
        uurl = Endpoint.items(openHABRootUrl: "http://192.168.0.199:8080").url
        url = uurl?.absoluteString ?? "unknown"

        if url == "" {
            if Preferences.demomode {
                uurl = Endpoint.items(openHABRootUrl: "http://demo.openhab.org:8080").url
                url = uurl?.absoluteString ?? "unknown"
                Preferences.ignoreSSL = false

            } else {
                uurl = Endpoint.items(openHABRootUrl: Preferences.remoteUrl).url
                url = uurl?.absoluteString ?? "unknown"
            }

        } else if uurl == nil {
            return
        }

        os_log("Loading items from %{PUBLIC}@", log: .default, type: .info, url)

        if NetworkConnection.shared == nil {
            NetworkConnection.initialize(ignoreSSL: Preferences.ignoreSSL, adapter: nil)
        }

        NetworkConnection.load(from: uurl!) { response in
            switch response.result {
            case .success:
                if let data = response.result.value {
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)
                        let codingDatas = try data.decoded(as: [OpenHABItem.CodingData].self, using: decoder)

                        self.items = [OpenHABItem]()

                        for codingDatum in codingDatas where codingDatum.openHABItem.type != OpenHABItem.ItemType.group {
                            self.items!.append(codingDatum.openHABItem)
                        }

                        os_log("Loaded items to cache: %{PUBLIC}d", log: .default, type: .info, self.items?.count ?? 0)

                        if mode == OpenHABItemCache.MODE_GET_ITEM {
                            let item = self.getItem(name!)

                            if item != nil {
                                completion(item!)
                            }
                        }
                    } catch {
                        os_log("%{PUBLIC}@ ", log: .default, type: .error, error.localizedDescription)
                    }
                }
            case let .failure(error):
                os_log("%{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
            }
        }
    }

    public func reload() {
        lastLoad = NSDate().timeIntervalSince1970

        print("ignoreSSL: \(Preferences.ignoreSSL)")
        print("localUrl: " + Preferences.localUrl)
        print("remoteUrl: " + Preferences.remoteUrl)
        print("username: " + Preferences.username)
        print("password: " + Preferences.password)

        var uurl = URL(string: url)
        uurl = Endpoint.items(openHABRootUrl: "http://192.168.0.199:8080").url
        url = uurl?.absoluteString ?? "unknown"

        if url == "" {
            if Preferences.demomode {
                uurl = Endpoint.items(openHABRootUrl: "http://demo.openhab.org:8080").url
                url = uurl?.absoluteString ?? "unknown"

            } else {
                uurl = Endpoint.items(openHABRootUrl: Preferences.remoteUrl).url
                url = uurl?.absoluteString ?? "unknown"
            }

        } else if uurl == nil {
            return
        }

        os_log("Loading items from %{PUBLIC}@", log: .default, type: .info, url)

        if NetworkConnection.shared == nil {
            NetworkConnection.initialize(ignoreSSL: Preferences.ignoreSSL, adapter: nil)
        }

        NetworkConnection.load(from: uurl!) { response in
            switch response.result {
            case .success:
                if let data = response.result.value {
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)
                        let codingDatas = try data.decoded(as: [OpenHABItem.CodingData].self, using: decoder)

                        self.items = [OpenHABItem]()

                        for codingDatum in codingDatas where codingDatum.openHABItem.type != OpenHABItem.ItemType.group {
                            self.items!.append(codingDatum.openHABItem)
                        }

                        os_log("Loaded items to cache: %{PUBLIC}d", log: .default, type: .info, self.items?.count ?? 0)

                    } catch {
                        os_log("%{PUBLIC}@ ", log: .default, type: .error, error.localizedDescription)
                    }
                }
            case let .failure(error):
                os_log("%{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
            }
        }
    }
}
