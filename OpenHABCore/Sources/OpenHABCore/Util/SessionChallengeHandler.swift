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
import os

@MainActor
public func onReceiveSessionTaskChallenge(with challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
    let host = challenge.protectionSpace.host
    let authenticationMethod = challenge.protectionSpace.authenticationMethod
    Logger.sessionChallenge.info("onReceiveSessionTaskChallenge host=\(host, privacy: .public), method=\(authenticationMethod, privacy: .public)")

    func logDecision(_ disposition: URLSession.AuthChallengeDisposition, reason: String) {
        Logger.sessionChallenge.info("Session task challenge decision host=\(host, privacy: .public), method=\(authenticationMethod, privacy: .public), disposition=\(String(describing: disposition), privacy: .public), reason=\(reason, privacy: .public)")
    }

    if challenge.previousFailureCount > 0 {
        let decision: URLSession.AuthChallengeDisposition = .cancelAuthenticationChallenge
        logDecision(decision, reason: "previous-failure")
        return (decision, nil)
    } else if authenticationMethod.isAny(of: NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodDefault) {
        let networkTracker = NetworkTracker.shared
        let activeConnection = await networkTracker.activeConnection

        var candidateConfigurations: [ConnectionConfiguration] = []
        if let activeConfiguration = activeConnection?.configuration {
            candidateConfigurations.append(activeConfiguration)
        }
        for configuration in await networkTracker.configuredConnections() where !candidateConfigurations.contains(configuration) {
            candidateConfigurations.append(configuration)
        }

        let proxyHost = activeConnection?.proxyURL?.host
        let matchedConfiguration = candidateConfigurations.first { configuration in
            URL(string: configuration.url)?.host == host
        }

        if let matchedConfiguration {
            let credential = URLCredential(user: matchedConfiguration.username, password: matchedConfiguration.password, persistence: .forSession)
            let decision: URLSession.AuthChallengeDisposition = .useCredential
            logDecision(decision, reason: "matched-connection-host")
            return (decision, credential)
        }

        if let proxyHost, host == proxyHost, let activeConfiguration = activeConnection?.configuration {
            let credential = URLCredential(user: activeConfiguration.username, password: activeConfiguration.password, persistence: .forSession)
            let decision: URLSession.AuthChallengeDisposition = .useCredential
            logDecision(decision, reason: "matched-active-proxy-host")
            return (decision, credential)
        }

        let candidateHosts = candidateConfigurations.compactMap { URL(string: $0.url)?.host }.joined(separator: ",")
        Logger.sessionChallenge.error("No host match for challenge host=\(host, privacy: .public). Candidate hosts: \(candidateHosts, privacy: .public)")
        let decision: URLSession.AuthChallengeDisposition = .performDefaultHandling
        logDecision(decision, reason: "no-host-match-default-handling")
        return (decision, nil)
    }
    let decision: URLSession.AuthChallengeDisposition = .performDefaultHandling
    logDecision(decision, reason: "unsupported-auth-method-default-handling")
    return (decision, nil)
}

@MainActor
public func onReceiveSessionChallenge(with challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
    let host = challenge.protectionSpace.host
    let authenticationMethod = challenge.protectionSpace.authenticationMethod
    Logger.sessionChallenge.info("onReceiveSessionChallenge host=\(host, privacy: .public), method=\(authenticationMethod, privacy: .public)")
    var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling

    func logDecision(_ disposition: URLSession.AuthChallengeDisposition, reason: String) {
        Logger.sessionChallenge.info("Session challenge decision host=\(host, privacy: .public), method=\(authenticationMethod, privacy: .public), disposition=\(String(describing: disposition), privacy: .public), reason=\(reason, privacy: .public)")
    }

    switch challenge.protectionSpace.authenticationMethod {
    case NSURLAuthenticationMethodServerTrust:
        // Check if the active connection has ignoreSSL enabled
        if let activeConnection = await NetworkTracker.shared.activeConnection,
           activeConnection.configuration.ignoreSSL,
           let serverTrust = challenge.protectionSpace.serverTrust {
            Logger.sessionChallenge.info("Ignoring SSL certificate validation (ignoreSSL enabled)")
            let decision: URLSession.AuthChallengeDisposition = .useCredential
            logDecision(decision, reason: "ignore-ssl-enabled")
            return (decision, URLCredential(trust: serverTrust))
        }
        let result = await CertificateManagers.serverCertificateManager.evaluateTrust(with: challenge)
        logDecision(result.0, reason: "server-trust-manager")
        return result
    case NSURLAuthenticationMethodClientCertificate:
        let result = CertificateManagers.clientCertificateManager.evaluateTrust(with: challenge)
        logDecision(result.0, reason: "client-certificate-manager")
        return result
    case NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodDefault:
        if challenge.previousFailureCount > 0 {
            disposition = .cancelAuthenticationChallenge
            logDecision(disposition, reason: "previous-failure")
            return (disposition, nil)
        }

        let networkTracker = NetworkTracker.shared
        let activeConnection = await networkTracker.activeConnection

        var candidateConfigurations: [ConnectionConfiguration] = []
        if let activeConfiguration = activeConnection?.configuration {
            candidateConfigurations.append(activeConfiguration)
        }
        for configuration in await networkTracker.configuredConnections() where !candidateConfigurations.contains(configuration) {
            candidateConfigurations.append(configuration)
        }

        let alwaysSend = Preferences.shared.currentHomePreferences.alwaysSendSameAuthenticationToWebView
        let matchedConfiguration = candidateConfigurations.first { configuration in
            URL(string: configuration.url)?.host == host
                || host == "home.myopenhab.org"
                || alwaysSend
        }

        if let matchedConfiguration {
            let credential = URLCredential(user: matchedConfiguration.username, password: matchedConfiguration.password, persistence: .forSession)
            let decision: URLSession.AuthChallengeDisposition = .useCredential
            logDecision(decision, reason: "matched-webview-host-or-always-send")
            return (decision, credential)
        }

        logDecision(disposition, reason: "no-webview-host-match-default-handling")
        return (disposition, nil)

    default:
        logDecision(disposition, reason: "unsupported-auth-method-default-handling")
        return (disposition, nil)
    }
}
