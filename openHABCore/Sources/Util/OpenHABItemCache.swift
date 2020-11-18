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

    public var items: [OpenHABItem]?
    public var url = ""
    public var lastLoad = NSDate().timeIntervalSince1970

    public func getItemNames(searchTerm: String?, types: [String]?, completion: @escaping ([NSString]) -> Void) {
        var ret = [NSString]()

        if items == nil {
            if #available(iOS 12.0, *) {
                reload(searchTerm: searchTerm, types: types, completion: completion)
            } else {
                // Fallback on earlier versions
            }
            return
        }

        for item in items! where (searchTerm == nil || item.name.contains(searchTerm ?? "")) && (types == nil || types!.contains(item.type?.rawValue ?? "unknownsksskl")) {
            ret.append(NSString(string: item.name))
        }

        completion(ret)
    }

    @available(iOS 12.0, *)
    public func getItem(name: String, completion: @escaping (OpenHABItem?) -> Void) {
        let now = NSDate().timeIntervalSince1970

        if items == nil || (now - lastLoad) > 10 { // More than 10 seconds - reload
            reload(name: name, completion: completion)
            return
        }

        for item in items! where item.name == name {
            completion(item)
            return
        }

        completion(nil)
    }

    func getItem(_ name: String) -> OpenHABItem? {
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
    public func reload(searchTerm: String?, types: [String]?, completion: @escaping ([NSString]) -> Void) {
        lastLoad = NSDate().timeIntervalSince1970

        let uurl = getURL()

        if uurl == nil {
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
                        try self.decodeItemsData(data)

                        var ret = [NSString]()

                        for item in self.items! where (searchTerm == nil || item.name.contains(searchTerm ?? "")) && (types == nil || types!.contains(item.type?.rawValue ?? "unknown")) {
                            ret.append(NSString(string: item.name))
                        }

                        completion(ret)
                    } catch {
                        os_log("%{PUBLIC}@ ", log: .default, type: .error, error.localizedDescription)
                    }
                }
            case let .failure(error):
                os_log("%{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
            }
        }
    }

    @available(iOS 12.0, *)
    public func reload(name: String, completion: @escaping (OpenHABItem?) -> Void) {
        lastLoad = NSDate().timeIntervalSince1970

        let uurl = getURL()

        if uurl == nil {
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
                        try self.decodeItemsData(data)

                        let item = self.getItem(name)

                        completion(item)

                    } catch {
                        os_log("%{PUBLIC}@ ", log: .default, type: .error, error.localizedDescription)
                    }
                }
            case let .failure(error):
                os_log("%{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
            }
        }
    }

    func getURL() -> URL? {
        var uurl: URL?

        if url == "" {
            if Preferences.demomode {
                uurl = Endpoint.items(openHABRootUrl: "http://demo.openhab.org:8080").url
                url = uurl?.absoluteString ?? "unknown"

            } else {
                uurl = Endpoint.items(openHABRootUrl: Preferences.remoteUrl).url
                url = uurl?.absoluteString ?? "unknown"
            }

        } else {
            uurl = URL(string: url)
        }

        return uurl
    }

    private func decodeItemsData(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)
        let codingDatas = try data.decoded(as: [OpenHABItem.CodingData].self, using: decoder)

        items = [OpenHABItem]()

        for codingDatum in codingDatas where codingDatum.openHABItem.type != OpenHABItem.ItemType.group {
            self.items!.append(codingDatum.openHABItem)
        }

        os_log("Loaded items to cache: %{PUBLIC}d", log: .default, type: .info, items?.count ?? 0)
    }
}
