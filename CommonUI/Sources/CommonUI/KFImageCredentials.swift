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

import Kingfisher
import OpenHABCore

public extension KFImage {
    /// Applies the openHAB Basic Auth request modifier when a connection is available.
    /// When `connection` is nil no modifier is attached and the image loads unauthenticated.
    func withOpenHABCredentials(for connection: ConnectionInfo?) -> KFImage {
        guard let connection else { return self }
        return requestModifier(OpenHABAccessTokenAdapter(connectionConfiguration: connection.configuration))
    }
}
