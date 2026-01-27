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
import Foundation
import OpenHABCore
import os

// MARK: - ViewModel

@MainActor
final class BonjourDiscoveryViewModel: ObservableObject {
    @Published var discoveredURLs: [String] = []
    @Published var isDiscovering = false

    private var bonjourService: BonjourService?
    private let logger = Logger(subsystem: "org.openhab", category: "BonjourDiscovery")

    /// Number of discovery cycles (more cycles help find multi-homed servers)
    var discoveryCycles = 2

    /// Duration of each discovery cycle in seconds
    var cycleDuration: TimeInterval = 5

    init() {}

    func discoverAll() {
        isDiscovering = true
        discoveredURLs.removeAll()

        let cycles = discoveryCycles
        let duration = cycleDuration
        logger.info("Starting Bonjour discovery (cycles: \(cycles), duration: \(duration)s)")

        bonjourService = BonjourService()
        bonjourService?.start(
            cycles: cycles,
            cycleDuration: duration,
            onUpdate: { [weak self] servers in
                Task { @MainActor in
                    self?.handleDiscoveredServers(servers)
                }
            },
            onComplete: { [weak self] in
                Task { @MainActor in
                    self?.completeDiscovery()
                }
            }
        )
    }

    private func handleDiscoveredServers(_ servers: [DiscoveredServer]) {
        for server in servers where !discoveredURLs.contains(server.url) {
            discoveredURLs.append(server.url)
            logger.notice("Discovered: \(server.url, privacy: .public)")
        }
    }

    private func completeDiscovery() {
        bonjourService?.stop()
        bonjourService = nil
        isDiscovering = false

        let urls = discoveredURLs
        let uniqueIPs = Set(urls.compactMap { URL(string: $0)?.host }).count
        logger.info("Discovery completed. Found \(urls.count) server(s) on \(uniqueIPs) IP(s)")
        for url in urls {
            logger.info("  \(url, privacy: .public)")
        }
    }

    func resetDiscoveredUrls() {
        bonjourService?.stop()
        bonjourService = nil
        discoveredURLs.removeAll()
        isDiscovering = false
    }
}
