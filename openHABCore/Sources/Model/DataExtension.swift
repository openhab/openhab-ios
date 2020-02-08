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

public protocol AnyDecoder {
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}

extension JSONDecoder: AnyDecoder {}
extension PropertyListDecoder: AnyDecoder {}

public extension Data {
    /// Decode this data into a value, optionally using a specific decoder.
    /// If no explicit encoder is passed, then the data is decoded as JSON.
    /// Inspired by https://www.swiftbysundell.com/posts/type-inference-powered-serialization-in-swift
    func decoded<T: Decodable>(as type: T.Type = T.self,
                               using decoder: AnyDecoder = JSONDecoder()) throws -> T {
        try decoder.decode(T.self, from: self)
    }
}
