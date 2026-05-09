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
import Testing

@testable import OpenHABCore

// MARK: - Test Helpers

private final class MockChallengeSender: NSObject, URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
    func performDefaultHandling(for challenge: URLAuthenticationChallenge) {}
    func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) {}
}

private func makeChallenge(host: String, method: String, previousFailureCount: Int = 0) -> URLAuthenticationChallenge {
    let protectionSpace = URLProtectionSpace(
        host: host,
        port: 443,
        protocol: NSURLProtectionSpaceHTTPS,
        realm: nil,
        authenticationMethod: method
    )
    return URLAuthenticationChallenge(
        protectionSpace: protectionSpace,
        proposedCredential: nil,
        previousFailureCount: previousFailureCount,
        failureResponse: nil,
        error: nil,
        sender: MockChallengeSender()
    )
}

private let localConfig = ConnectionConfiguration(
    url: "https://local.openhab.org",
    username: "localuser",
    password: "localpass",
    priority: 0
)

private let remoteConfig = ConnectionConfiguration(
    url: "https://remote.openhab.org",
    username: "remoteuser",
    password: "remotepass",
    priority: 10
)

private let proxyURL = URL(string: "https://proxy.openhab.org")!

private func makeMockTracker(activeConnection: ConnectionInfo? = nil, configurations: [ConnectionConfiguration] = []) async -> NetworkTracker {
    let tracker = NetworkTracker()
    if let activeConnection {
        await tracker.setMockConnection(activeConnection)
    }
    await tracker.setMockConnectionConfigurations(configurations)
    return tracker
}

// MARK: - onReceiveSessionChallenge default case Tests

@Suite("onReceiveSessionChallenge default case")
struct SessionChallengeDefaultCaseTests {
    @Test("Cancels challenge when previousFailureCount > 0")
    func cancelsOnPreviousFailure() async {
        let challenge = makeChallenge(
            host: "local.openhab.org",
            method: NSURLAuthenticationMethodNegotiate,
            previousFailureCount: 1
        )
        let (disposition, credential) = await onReceiveSessionChallenge(with: challenge, networkTracker: NetworkTracker())
        #expect(disposition == .cancelAuthenticationChallenge)
        #expect(credential == nil)
    }

    @Test("Performs default handling without credential lookup")
    func defaultHandlingWithoutCredentialLookup() async {
        let connection = ConnectionInfo(configuration: localConfig, version: 1)
        let tracker = await makeMockTracker(activeConnection: connection, configurations: [localConfig])

        let challenge = makeChallenge(
            host: "local.openhab.org",
            method: NSURLAuthenticationMethodNegotiate
        )
        let (disposition, credential) = await onReceiveSessionChallenge(with: challenge, networkTracker: tracker)
        #expect(disposition == .performDefaultHandling)
        #expect(credential == nil)
    }
}

// MARK: - onReceiveSessionTaskChallenge Tests

@Suite("onReceiveSessionTaskChallenge")
struct SessionTaskChallengeTests {
    @Test("Cancels challenge when previousFailureCount > 0")
    func cancelsOnPreviousFailure() async {
        let challenge = makeChallenge(
            host: "local.openhab.org",
            method: NSURLAuthenticationMethodHTTPBasic,
            previousFailureCount: 1
        )
        let (disposition, credential) = await onReceiveSessionTaskChallenge(with: challenge, networkTracker: NetworkTracker())
        #expect(disposition == .cancelAuthenticationChallenge)
        #expect(credential == nil)
    }

    @Test("Performs default handling for unsupported auth method")
    func defaultHandlingForUnsupportedMethod() async {
        let challenge = makeChallenge(
            host: "local.openhab.org",
            method: NSURLAuthenticationMethodNTLM
        )
        let (disposition, credential) = await onReceiveSessionTaskChallenge(with: challenge, networkTracker: NetworkTracker())
        #expect(disposition == .performDefaultHandling)
        #expect(credential == nil)
    }

    @Test("Returns credential when host matches a configured connection")
    func returnsCredentialForMatchedHost() async {
        let connection = ConnectionInfo(configuration: localConfig, version: 1)
        let tracker = await makeMockTracker(activeConnection: connection, configurations: [localConfig])

        let challenge = makeChallenge(
            host: "local.openhab.org",
            method: NSURLAuthenticationMethodHTTPBasic
        )
        let (disposition, credential) = await onReceiveSessionTaskChallenge(with: challenge, networkTracker: tracker)
        #expect(disposition == .useCredential)
        #expect(credential?.user == "localuser")
        #expect(credential?.hasPassword == true)
    }

    @Test("Returns credential for NSURLAuthenticationMethodDefault")
    func returnsCredentialForDefaultMethod() async {
        let connection = ConnectionInfo(configuration: localConfig, version: 1)
        let tracker = await makeMockTracker(activeConnection: connection, configurations: [localConfig])

        let challenge = makeChallenge(
            host: "local.openhab.org",
            method: NSURLAuthenticationMethodDefault
        )
        let (disposition, credential) = await onReceiveSessionTaskChallenge(with: challenge, networkTracker: tracker)
        #expect(disposition == .useCredential)
        #expect(credential?.user == "localuser")
    }

    @Test("Performs default handling when no host matches")
    func defaultHandlingForNoHostMatch() async {
        let tracker = await makeMockTracker(configurations: [localConfig])

        let challenge = makeChallenge(
            host: "unknown.example.com",
            method: NSURLAuthenticationMethodHTTPBasic
        )
        let (disposition, credential) = await onReceiveSessionTaskChallenge(with: challenge, networkTracker: tracker)
        #expect(disposition == .performDefaultHandling)
        #expect(credential == nil)
    }

    @Test("Returns credential when host matches proxy URL of active connection")
    func returnsCredentialForProxyHost() async {
        let connection = ConnectionInfo(configuration: remoteConfig, version: 1, proxyURL: proxyURL)
        let tracker = await makeMockTracker(activeConnection: connection, configurations: [remoteConfig])

        let challenge = makeChallenge(
            host: "proxy.openhab.org",
            method: NSURLAuthenticationMethodHTTPBasic
        )
        let (disposition, credential) = await onReceiveSessionTaskChallenge(with: challenge, networkTracker: tracker)
        #expect(disposition == .useCredential)
        #expect(credential?.user == "remoteuser")
    }
}
