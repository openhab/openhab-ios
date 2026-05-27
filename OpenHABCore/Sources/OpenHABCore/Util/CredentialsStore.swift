// Copyright (c) 2010-2026 Contributors to the openHAB project
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
import os.log
import Security

/// Stores connection credentials (username + password) in the system Keychain, keyed by home UUID and connection type.
/// Each home can have independent credentials for its local and remote connections.
public enum CredentialsStore {
    public enum ConnectionType: String {
        case local
        case remote
    }

    private static let service = "org.openhab.app.credentials"

    private static func account(homeId: UUID, type: ConnectionType) -> String {
        "\(homeId.uuidString).\(type.rawValue)"
    }

    /// Stores credentials for the given home and connection type, creating or updating the Keychain entry.
    public static func store(username: String, password: String, homeId: UUID, type: ConnectionType) {
        let account = account(homeId: homeId, type: type)
        guard let data = try? JSONEncoder().encode(["username": username, "password": password]) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]

        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        if status != errSecSuccess {
            Logger.preferences.error("CredentialsStore: failed to store credentials for \(account), status: \(status)")
        }
    }

    /// Returns stored credentials for the given home and connection type, or nil if none are stored.
    public static func retrieve(homeId: UUID, type: ConnectionType) -> (username: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(homeId: homeId, type: type),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let payload = try? JSONDecoder().decode([String: String].self, from: data),
              let username = payload["username"],
              let password = payload["password"] else {
            if status != errSecItemNotFound {
                Logger.preferences.debug("CredentialsStore: retrieve returned status \(status) for \(account(homeId: homeId, type: type))")
            }
            return nil
        }
        return (username, password)
    }

    /// Deletes credentials for the given home and connection type.
    public static func delete(homeId: UUID, type: ConnectionType) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(homeId: homeId, type: type)
        ]
        SecItemDelete(query as CFDictionary)
    }
}
