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

import Combine
import Kingfisher
import OpenHABCore
import os.log
import SwiftUI

@MainActor
class NetworkConnectionService: ObservableObject {
    // MARK: - Published state

    @Published var certificateAlert: CertificateAlertState?

    // MARK: - Private state

    private var cancellables = Set<AnyCancellable>()

    struct CertificateAlertState: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let delegate: HTTPClientDelegate
    }

    init() {
        setupTracker()
    }

    // MARK: - Network Tracker

    private func setupTracker() {
        NotificationCenter.default.addObserver(
            forName: .evaluateServerTrust,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard
                let summary = notification.userInfo?["summary"] as? String,
                let domain = notification.userInfo?["domain"] as? String,
                let delegate = notification.object as? HTTPClientDelegate
            else { return }
            Task { @MainActor in
                self?.handleCertificateTrust(
                    summary: summary,
                    domain: domain,
                    delegate: delegate,
                    messageTemplateKey: "ssl_certificate_invalid"
                )
            }
        }

        NotificationCenter.default.addObserver(
            forName: .evaluateCertificateMismatch,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard
                let summary = notification.userInfo?["summary"] as? String,
                let domain = notification.userInfo?["domain"] as? String,
                let delegate = notification.object as? HTTPClientDelegate
            else { return }
            Task { @MainActor in
                self?.handleCertificateTrust(
                    summary: summary,
                    domain: domain,
                    delegate: delegate,
                    messageTemplateKey: "ssl_certificate_no_match"
                )
            }
        }

        NotificationCenter.default.addObserver(
            forName: .acceptedServerCertificatesChanged,
            object: nil,
            queue: nil
        ) { _ in
            Task { @MainActor in
                await WatchMessageService.singleton.syncPreferencesToWatch()
                await NetworkTracker.shared.restartTracking()
            }
        }

        // TODO: DEVELOP MERGE (regression) — sitemap list sometimes fails to reload on home switch.
        // This subscription drives startTracking → activeConnection change → MenuDataService reload.
        // Pre-merge this used `$currentHomePreferences` (raw stored value); develop's Preferences refactor
        // required switching to `currentHomePreferencesPublisher`, which additionally injects Keychain
        // credentials via `.map`. Emission timing looks equivalent ($_currentHomePreferences), but the
        // 500 ms debounce + credential-injecting map is the prime suspect for the intermittent missed
        // reload. Investigate whether an emission is being coalesced/dropped or whether the new
        // connection compares equal so `$activeConnection` doesn't re-emit. Deferred for later.
        Preferences.shared.currentHomePreferencesPublisher
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { homeSettings in
                let trackedConnections = homeSettings.trackedConnections
                let sseCommandItem = homeSettings.sseCommandItem

                Task {
                    await NetworkTracker.shared.startTracking(connectionConfigurations: trackedConnections)
                    if !homeSettings.demomode {
                        await ItemEventStream.trackItems(sseCommandItem.isEmpty ? [] : [sseCommandItem])
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Certificate Trust

    private func handleCertificateTrust(summary: String, domain: String, delegate: HTTPClientDelegate, messageTemplateKey: String) {
        let title = NSLocalizedString("ssl_certificate_warning", comment: "")
        let message = String(format: NSLocalizedString(messageTemplateKey, comment: ""), summary, domain)
        certificateAlert = CertificateAlertState(title: title, message: message, delegate: delegate)
    }

    func certificateAlertAction(_ result: CertificateEvaluateResult) {
        certificateAlert?.delegate.completeEvaluation(result)
        certificateAlert = nil
    }
}

// MARK: - Kingfisher authentication

extension NetworkConnectionService: AuthenticationChallengeResponsible {
    nonisolated func downloader(_ downloader: ImageDownloader,
                                didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await onReceiveSessionChallenge(with: challenge)
    }

    nonisolated func downloader(_ downloader: ImageDownloader,
                                task: URLSessionTask,
                                didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await onReceiveSessionTaskChallenge(with: challenge)
    }
}
