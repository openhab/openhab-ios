// Copyright (c) 2010-2023 Contributors to the openHAB project
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

// swiftlint:disable file_types_order
public class Future<Value> {
    public typealias Result = Swift.Result<Value, Error>

    fileprivate var result: Result? {
        // Observe whenever a result is assigned, and report it:
        didSet { result.map(report) }
    }

    private var callbacks = [(Result) -> Void]()

    public func observe(using callback: @escaping (Result) -> Void) {
        // If a result has already been set, call the callback directly:
        if let result {
            return callback(result)
        }

        callbacks.append(callback)
    }

    private func report(result: Result) {
        callbacks.forEach { $0(result) }
        callbacks = []
    }
}

public class Promise<Value>: Future<Value> {
    public init(value: Value? = nil) {
        super.init()

        // If the value was already known at the time the promise
        // was constructed, we can report it directly:
        result = value.map(Result.success)
    }

    public func resolve(with value: Value) {
        result = .success(value)
    }

    public func reject(with error: Error) {
        result = .failure(error)
    }
}

public enum NetworkingError: Error {
    case invalidURL
}

public typealias Networking = (Endpoint) -> Future<Data>

extension Future {
    func chained<T>(using closure: @escaping (Value) throws -> Future<T>) -> Future<T> {
        // We'll start by constructing a "wrapper" promise that will be
        // returned from this method:
        let promise = Promise<T>()

        // Observe the current future:
        observe { result in
            switch result {
            case let .success(value):
                do {
                    // Attempt to construct a new future using the value
                    // returned from the first one:
                    let future = try closure(value)

                    // Observe the "nested" future, and once it
                    // completes, resolve/reject the "wrapper" future:
                    future.observe { result in
                        switch result {
                        case let .success(value):
                            promise.resolve(with: value)
                        case let .failure(error):
                            promise.reject(with: error)
                        }
                    }
                } catch {
                    promise.reject(with: error)
                }
            case let .failure(error):
                promise.reject(with: error)
            }
        }

        return promise
    }
}

public extension Future {
    func transformed<T>(with closure: @escaping (Value) throws -> T) -> Future<T> {
        chained { value in
            try Promise(value: closure(value))
        }
    }
}

// extension Future where Value == Data {
//    func decoded<T: Decodable>() -> Future<T> {
//        decoded(as: T.self, using: JSONDecoder())
//    }
// }

public extension Future where Value == Data {
    func decoded<T: Decodable>(as type: T.Type = T.self, using decoder: JSONDecoder = .init()) -> Future<T> {
        transformed { data in
            try decoder.decode(T.self, from: data)
        }
    }
}
