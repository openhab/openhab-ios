//
//  Endpoint.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 12.02.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation

struct Endpoint {
    let baseURL: String
    let path: String
    let queryItems: [URLQueryItem]
}

extension Endpoint {
    // We still have to keep 'url' as an optional, since we're
    // dealing with dynamic components that could be invalid.
    var url: URL? {
        var components = URLComponents(string: baseURL)
        components?.path = path
        components?.queryItems = queryItems
        return components?.url
    }
}

enum Result<Value, Error: Swift.Error> {
    case success(Value)
    case failure(Error)
}

enum LoadingError: Error {
    case invalidFile(Error)
    case invalidData(Error)
    case decodingFailed(Error)
    case invalidURL(Error)
}

typealias Handler = (Result<Data, LoadingError>) -> Void
