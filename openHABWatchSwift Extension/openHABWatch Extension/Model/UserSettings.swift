//
//  UserSettings.swift
//  openHABWatchSwift Extension
//
//  Created by Tim Müller-Seydlitz on 08.01.20.
//  Copyright © 2020 openHAB e.V. All rights reserved.
//

import Combine
import Foundation

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

final class UserSettings: ObservableObject {

    static let shared = UserSettings()

    let objectWillChange = PassthroughSubject<Void, Never>()

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
    var username: String {
        willSet {
            objectWillChange.send()
        }
    }

    @UserDefault("password", defaultValue: "")
    var password: String {
        willSet {
            objectWillChange.send()
        }
    }

    @UserDefault("ignoreSSL", defaultValue: true)
    var ignoreSSL: Bool {
        willSet {
            objectWillChange.send()
        }
    }

}
