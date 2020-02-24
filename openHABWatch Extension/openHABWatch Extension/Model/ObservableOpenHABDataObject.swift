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

import Combine
import Foundation
import OpenHABCoreWatch

@propertyWrapper
struct UserDefault<T> {
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

    init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
}

final class ObservableOpenHABDataObject: DataObject, ObservableObject {
    static let shared = ObservableOpenHABDataObject()

    var openHABVersion: Int = 2

    let objectWillChange = PassthroughSubject<Void, Never>()
    let objectRefreshed = PassthroughSubject<Void, Never>()

    @UserDefault("rootUrl", defaultValue: "")
    var openHABRootUrl: String {
        willSet {
            objectWillChange.send()
        }
    }

    @UserDefault("localUrl", defaultValue: "")
    var localUrl: String {
        willSet {
            objectWillChange.send()
        }
    }

    @UserDefault("remoteUrl", defaultValue: "")
    var remoteUrl: String {
        willSet {
            objectWillChange.send()
        }
    }

    @UserDefault("sitemapName", defaultValue: "")
    var sitemapName: String {
        willSet {
            objectWillChange.send()
        }
    }

    @UserDefault("username", defaultValue: "")
    var openHABUsername: String {
        willSet {
            objectWillChange.send()
        }
    }

    @UserDefault("password", defaultValue: "")
    var openHABPassword: String {
        willSet {
            objectWillChange.send()
        }
    }

    @UserDefault("ignoreSSL", defaultValue: true)
    var ignoreSSL: Bool {
        willSet {
            objectWillChange.send()
            NetworkConnection.shared.serverCertificateManager.ignoreSSL = newValue
        }
    }

    @UserDefault("alwaysSendCreds", defaultValue: false)
    var openHABAlwaysSendCreds: Bool {
        willSet {
            objectWillChange.send()
        }
    }

    @UserDefault("haveReceivedAppContext", defaultValue: false)
    var haveReceivedAppContext: Bool {
        willSet {
            objectRefreshed.send()
        }
    }
}

extension ObservableOpenHABDataObject {
    convenience init(openHABRootUrl: String) {
        self.init()
        self.openHABRootUrl = openHABRootUrl
    }
}
