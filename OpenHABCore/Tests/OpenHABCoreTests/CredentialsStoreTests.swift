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

@testable import OpenHABCore
import Testing

/// These tests require the openHAB app as the test host so the xctest process inherits
/// the keychain-access-groups entitlement. Without it SecItemAdd returns errSecMissingEntitlement
/// and all store/retrieve tests fail. Configure the test scheme to use openHAB.app as the host.
@Suite("CredentialsStore Tests", .serialized, .disabled("Requires openHAB.app test host for Keychain entitlement"))
struct CredentialsStoreTests {
    private let homeId = UUID()

    @Test func storeAndRetrieve() {
        CredentialsStore.store(username: "alice", password: "s3cr3t", homeId: homeId, type: .local)
        let creds = CredentialsStore.retrieve(homeId: homeId, type: .local)
        #expect(creds?.username == "alice")
        #expect(creds?.password == "s3cr3t")
        CredentialsStore.delete(homeId: homeId, type: .local)
    }

    @Test func localAndRemoteAreIndependent() {
        CredentialsStore.store(username: "local-user", password: "local-pass", homeId: homeId, type: .local)
        CredentialsStore.store(username: "remote-user", password: "remote-pass", homeId: homeId, type: .remote)
        #expect(CredentialsStore.retrieve(homeId: homeId, type: .local)?.username == "local-user")
        #expect(CredentialsStore.retrieve(homeId: homeId, type: .remote)?.username == "remote-user")
        CredentialsStore.delete(homeId: homeId, type: .local)
        CredentialsStore.delete(homeId: homeId, type: .remote)
    }

    @Test func updateOverwritesPreviousCredentials() {
        CredentialsStore.store(username: "first", password: "pass1", homeId: homeId, type: .remote)
        CredentialsStore.store(username: "second", password: "pass2", homeId: homeId, type: .remote)
        let creds = CredentialsStore.retrieve(homeId: homeId, type: .remote)
        #expect(creds?.username == "second")
        #expect(creds?.password == "pass2")
        CredentialsStore.delete(homeId: homeId, type: .remote)
    }

    @Test func deleteRemovesCredentials() {
        CredentialsStore.store(username: "bob", password: "hunter2", homeId: homeId, type: .local)
        CredentialsStore.delete(homeId: homeId, type: .local)
        #expect(CredentialsStore.retrieve(homeId: homeId, type: .local) == nil)
    }

    @Test func retrieveReturnsNilForUnknownHomeId() {
        #expect(CredentialsStore.retrieve(homeId: UUID(), type: .local) == nil)
    }
}
