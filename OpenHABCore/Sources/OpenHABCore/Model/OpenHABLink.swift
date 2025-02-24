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

class OpenHABLink: Decodable {
    public var type: String?
    public var url: String?

    init(type: String?, url: String?) {
        self.type = type
        self.url = url
    }
}

extension OpenHABLink {
    convenience init?(_ links: Components.Schemas.Links?) {
        if let links {
            self.init(type: links._type, url: links.url)
        } else {
            return nil
        }
    }
}
