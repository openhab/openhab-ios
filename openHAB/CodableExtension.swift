// Copyright (c) 2010-2019 Contributors to the openHAB project
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

extension KeyedDecodingContainerProtocol {
    func decode<T: Decodable>(forKey key: Key) throws -> T {
        return try decode(T.self, forKey: key)
    }

    func decodeIfPresent<T: Decodable>(forKey key: Key) throws -> T? {
        return try decodeIfPresent(T.self, forKey: key)
    }

    func decode<T: Decodable>(forKey key: Key, default defaultValue: T) throws -> T {
        return try decodeIfPresent(T.self, forKey: key) ?? defaultValue
    }
}
