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

import Foundation

struct OpenHABLink: Decodable {
    var type: String?
    var url: String?
}

extension OpenHABLink {
    init?(_ links: Components.Schemas.Links?) {
        if let links {
            self.init(type: links._type, url: links.url)
        } else {
            return nil
        }
    }
}
