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

    public func reload() {
        guard let uurl = URL(string: url) else { return }
        os_log("Loading items from %{PUBLIC}@", log: .default, type: .info, url)

        NetworkConnection.load(from: uurl) { response in
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
