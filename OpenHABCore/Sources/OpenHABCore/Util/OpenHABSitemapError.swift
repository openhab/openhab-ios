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

public enum OpenHABSitemapError: LocalizedError {
    case noActiveConnection
    case invalidConnectionConfiguration

    public var errorDescription: String? {
        switch self {
        case .noActiveConnection:
            String(localized: "no_active_connection", comment: "No active connection available.")
        case .invalidConnectionConfiguration:
            String(localized: "invalid_connection_configuration", comment: "Invalid connection configuration.")
        }
    }
}
