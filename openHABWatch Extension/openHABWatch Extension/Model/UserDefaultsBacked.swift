// Copyright (c) 2010-2021 Contributors to the openHAB project
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

@propertyWrapper
struct UserDefaultsBacked<T> {
    let key: String
    let defaultValue: T
    // https://www.swiftbysundell.com/articles/property-wrappers-in-swift/
    var storage: UserDefaults = .standard

    public var wrappedValue: T {
        get {
            storage.object(forKey: key) as? T ?? defaultValue
        }
        set {
            storage.set(newValue, forKey: key)
        }
    }
}

/// Convenience initializer when UserDefaults is optional.
extension UserDefaultsBacked where T: ExpressibleByNilLiteral {
    init(key: String, storage: UserDefaults = .standard) {
        self.init(key: key, defaultValue: nil, storage: storage)
    }
}
