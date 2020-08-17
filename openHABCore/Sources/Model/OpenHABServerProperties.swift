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

public class OpenHABServerProperties: Decodable {
    class OpenHABLink: Decodable {
        public var type = ""
        public var url = ""
    }

    let version: String
    let links: [OpenHABLink]

    public var habPanelUrl: String? {
        linkUrl(byType: "habpanel")
    }

    public func linkUrl(byType type: String?) -> String? {
        if let index = links.firstIndex(where: { $0.type == type }) {
            return links[index].url
        } else {
            return nil
        }
    }
}
