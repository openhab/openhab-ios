// Copyright (c) 2010-2022 Contributors to the openHAB project
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
import OpenHABCore

final class ObservableOpenHABDataObject: DataObject, ObservableObject {
    static let shared = ObservableOpenHABDataObject()

    var openHABVersion: Int = 2

    let objectWillChange = PassthroughSubject<Void, Never>()
    let objectRefreshed = PassthroughSubject<Void, Never>()

    @UserDefaultsBacked(key: "rootUrl", defaultValue: "")
    var openHABRootUrl: String {
        willSet {
            objectWillChange.send()
        }
    }

    @UserDefaultsBacked(key: "localUrl", defaultValue: "")
    var localUrl: String {
        willSet {
            objectWillChange.send()
        }
    }

    @UserDefaultsBacked(key: "remoteUrl", defaultValue: "")
    var remoteUrl: String {
        willSet {
            objectWillChange.send()
        }
    }

    @UserDefaultsBacked(key: "sitemapName", defaultValue: "")
    var sitemapName: String {
        willSet {
            objectWillChange.send()
        }
    }

    @UserDefaultsBacked(key: "username", defaultValue: "")
    var openHABUsername: String {
        willSet {
            objectWillChange.send()
        }
    }

    @UserDefaultsBacked(key: "password", defaultValue: "")
    var openHABPassword: String {
        willSet {
            objectWillChange.send()
        }
    }

    @UserDefaultsBacked(key: "ignoreSSL", defaultValue: true)
    var ignoreSSL: Bool {
        willSet {
            objectWillChange.send()
            NetworkConnection.shared.serverCertificateManager.ignoreSSL = newValue
        }
    }

    @UserDefaultsBacked(key: "alwaysSendCreds", defaultValue: false)
    var openHABAlwaysSendCreds: Bool {
        willSet {
            objectWillChange.send()
        }
    }

    @UserDefaultsBacked(key: "haveReceivedAppContext", defaultValue: false)
    var haveReceivedAppContext: Bool {
        didSet {
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
