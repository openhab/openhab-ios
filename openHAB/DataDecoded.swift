//
//  DataDecoded.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 30.07.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation

protocol AnyDecoder {
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}

extension JSONDecoder: AnyDecoder {}
extension PropertyListDecoder: AnyDecoder {}

// Inspired by https://www.swiftbysundell.com/posts/type-inference-powered-serialization-in-swift
extension Data {
    func decoded<T: Decodable>(using decoder: AnyDecoder = JSONDecoder()) throws -> T {
        return try decoder.decode(T.self, from: self)
    }
}
