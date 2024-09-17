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

import Foundation

public class OpenHABUiTile {
    public var name = ""
    public var url = ""
    public var imageUrl = ""

    public init(name: String, url: String, imageUrl: String) {
        self.name = name
        self.url = url
        self.imageUrl = imageUrl
    }
}

extension OpenHABUiTile {
    convenience init(_ tile: Components.Schemas.TileDTO) {
        self.init(name: tile.name.orEmpty, url: tile.url.orEmpty, imageUrl: tile.imageUrl.orEmpty)
    }
}
