//
//  UserSettings.swift
//  openHABWatchSwift Extension
//
//  Created by Tim Müller-Seydlitz on 08.01.20.
//  Copyright © 2020 openHAB e.V. All rights reserved.
//

import Combine
import Foundation
import OpenHABCoreWatch

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T

    public var wrappedValue: T {
        get {
            return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    init(_ key: String, defaultValue: T) {
           self.key = key
           self.defaultValue = defaultValue
    }
}

final class UserSettings: DataObject, ObservableObject {

    static let shared = UserSettings()

    var openHABVersion: Int = 2

    let objectWillChange = PassthroughSubject<Void, Never>()

    @UserDefault("localUrl", defaultValue: "")
    var openHABRootUrl: String {
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

}

extension UserSettings {
     convenience init(openHABRootUrl: String) {
         self.init()
         self.openHABRootUrl = openHABRootUrl
     }
 }
