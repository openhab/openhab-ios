// Copyright (c) 2010-2025 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

@preconcurrency import Combine
import CoreFoundation
import Foundation
import Network
import os

enum BonjourServiceType: String {
    case https = "_openhab-server-ssl._tcp"
    case http = "_openhab-server._tcp"

    var endpoint: NWBrowser.Descriptor {
        .bonjour(type: rawValue, domain: "local.")
    }

    var scheme: String {
        switch self {
        case .https: "https"
        case .http: "http"
        }
    }
}

// @available(watchOS, unavailable)
@MainActor
final class BonjourDiscoveryViewModel: ObservableObject {
    @Published var discoveredURLs: [String] = []
    @Published var isDiscovering = false

    private var browsers: [BonjourServiceType: NWBrowser] = [:]
    private var timeoutTasks: [BonjourServiceType: Task<Void, Never>] = [:]
    private var pendingResolutions: Set<String> = []
    // Removed discoveredServers deduplication as it was preventing multiple addresses for same service
    private let logger = Logger(subsystem: "org.openhab", category: "BonjourDiscovery")
    private let timeoutInterval: TimeInterval = 20

    init() {}

    private func stopDiscovering() {
        isDiscovering = false
    }

    private func timeout(serviceType: BonjourServiceType) {
        browsers[serviceType]?.cancel()
        browsers[serviceType] = nil
        timeoutTasks[serviceType]?.cancel()
        timeoutTasks[serviceType] = nil
    }

    private func addDiscoveredUrl(_ url: String) {
        discoveredURLs.append(url)
    }

    func resetDiscoveredUrls() {
        discoveredURLs.removeAll()
        pendingResolutions.removeAll()
    }
}

extension BonjourDiscoveryViewModel {
    func discoverAll() {
        discoverAllWithRetry(attempt: 1)
    }

    private func discoverAllWithRetry(attempt: Int, maxAttempts: Int = 2) {
        isDiscovering = true
        if attempt == 1 {
            discoveredURLs.removeAll()
            pendingResolutions.removeAll()
        }
        stopAllDiscovery()

        var completedDiscoveries = 0
        var discoveryCompleted = false
        let totalDiscoveries = 2

        let checkCompletion: @Sendable () -> Void = {
            self.logger.trace("checkCompletion")
            Task { @MainActor in
                guard !discoveryCompleted else { return }

                completedDiscoveries += 1
                self.logger.debug("Discovery browsing completed: \(completedDiscoveries)/\(totalDiscoveries) (attempt \(attempt))")
                if completedDiscoveries >= totalDiscoveries {
                    // Wait a bit more for pending hostname resolutions to complete
                    self.logger.debug("All browsers finished, waiting for pending resolutions: \(self.pendingResolutions.count)")
                    Task {
                        // Wait up to 8 more seconds for hostname resolutions
                        for i in 1 ... 8 {
                            do {
                                try await Task.sleep(for: .seconds(1))
                            } catch {
                                break
                            }
                            let shouldComplete = await MainActor.run {
                                self.pendingResolutions.isEmpty && !discoveryCompleted
                            }
                            if shouldComplete {
                                await MainActor.run {
                                    discoveryCompleted = true
                                    self.logger.debug("All resolutions completed after \(i) second(s)")
                                    self.completeDiscovery(attempt: attempt, maxAttempts: maxAttempts)
                                }
                                return
                            }
                        }
                        // Force completion after timeout
                        await MainActor.run {
                            if !discoveryCompleted {
                                discoveryCompleted = true
                                self.logger.debug("Resolution timeout reached, completing with \(self.pendingResolutions.count) pending")
                                self.completeDiscovery(attempt: attempt, maxAttempts: maxAttempts)
                            }
                        }
                    }
                }
            }
        }

        logger.info("🔍 Starting parallel discovery (attempt \(attempt)/\(maxAttempts))")
        discover(using: .https, completion: checkCompletion)
        discover(using: .http, completion: checkCompletion)
    }

    private func completeDiscovery(attempt: Int, maxAttempts: Int) {
        let foundCount = discoveredURLs.count
        let uniqueIPs = Set(discoveredURLs.compactMap { URL(string: $0)?.host }).count

        if foundCount == 0, attempt < maxAttempts {
            logger.info("🔄 No servers found on attempt \(attempt), retrying...")
            Task {
                do {
                    try await Task.sleep(for: .seconds(2))
                } catch {
                    return
                }
                discoverAllWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts)
            }
        } else {
            stopDiscovering()
            if foundCount > 0 {
                logger.info("🎉 Discovery completed after \(attempt) attempt(s). Found \(foundCount) server(s) on \(uniqueIPs) IP(s)")
                for url in discoveredURLs {
                    logger.info("  📍 \(url, privacy: .public)")
                }
            } else {
                logger.info("🔍 Discovery completed after \(attempt) attempt(s). No openHAB servers found.")
            }
        }
    }

    private func discover(using serviceType: BonjourServiceType, completion: @Sendable @escaping () -> Void) {
        logger.info("🔍 Starting \(serviceType.rawValue, privacy: .public) discovery…")

        // Cancel existing browser for this service type
        browsers[serviceType]?.cancel()
        timeoutTasks[serviceType]?.cancel()

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: serviceType.endpoint, using: parameters)
        browsers[serviceType] = browser

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            Task { @MainActor in
                for result in results {
                    switch result.endpoint {
                    case let .hostPort(host, port):
                        self.logger.debug("🔍 Discovered \(String(describing: host)):\(String(describing: port))")

                    case let .service(name, type, domain, _):
                        self.resolve(endpoint: .service(name: name, type: type, domain: domain, interface: nil), scheme: serviceType.scheme)

                    default:
                        break
                    }
                }
            }
        }

        browser.stateUpdateHandler = { [weak self] newState in
            guard let self else { return }
            switch newState {
            case .ready:
                logger.info("🌐 NWBrowser ready for \(serviceType.rawValue, privacy: .public)")
            case let .failed(error):
                logger.error("❌ NWBrowser failed for \(serviceType.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")

                // Don't call completion here immediately, let the timeout handle it
                // This prevents premature completion when one browser fails but the other succeeds
                Task { @MainActor in
                    timeout(serviceType: serviceType)
                }
            default:
                break
            }
        }

        browser.start(queue: .main)

        // Timeout with individual tracking
        let timeoutInterval = timeoutInterval
        let timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(timeoutInterval))
            } catch {
                return
            }
            guard let self else { return }
            await MainActor.run {
                logger.debug("🕐 Timeout reached for \(serviceType.rawValue, privacy: .public), pending resolutions: \(self.pendingResolutions.count)")
                timeout(serviceType: serviceType)
                logger.info("⏱️ Discovery for \(serviceType.rawValue, privacy: .public) completed.")
                completion()
            }
        }
        timeoutTasks[serviceType] = timeoutTask
    }

    private func stopAllDiscovery() {
        for browser in browsers.values {
            browser.cancel()
        }
        browsers.removeAll()

        for task in timeoutTasks.values {
            task.cancel()
        }
        timeoutTasks.removeAll()
        pendingResolutions.removeAll()
    }

    private func resolve(endpoint: NWEndpoint, scheme: String) {
        guard case let .service(name, type, domain, _) = endpoint else {
            logger.debug("❌ Not a service endpoint: \(String(describing: endpoint))")
            return
        }

        // Normalize service name to prevent duplicates from numbered instances like "openhab-ssl (1)", "openhab-ssl (2)"
        let normalizedName = name.replacingOccurrences(of: #" \(\d+\)"#, with: "", options: .regularExpression)
        let serviceKey = "\(normalizedName).\(type).\(domain)"

        pendingResolutions.insert(serviceKey)
        logger.debug("🔍 Resolving \(scheme, privacy: .public) service: \(name, privacy: .public) (\(type, privacy: .public))")
        let serviceEndpoint = NWEndpoint.service(name: name, type: type, domain: domain, interface: nil)

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        parameters.requiredInterfaceType = .other // Allow all interface types (wifi, ethernet, etc.)

        let connection = NWConnection(to: serviceEndpoint, using: parameters)

        // Add connection timeout
        Task {
            do {
                try await Task.sleep(for: .seconds(10)) // 10 second timeout for individual connections
            } catch {
                return
            }
            logger.warning("⏰ Connection timeout for \(serviceKey, privacy: .public)")
            Task { @MainActor in
                pendingResolutions.remove(serviceKey)
            }
            connection.cancel()
        }

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }

            logger.debug("🔗 Connection state for \(serviceKey, privacy: .public): \(String(describing: state))")

            if case .ready = state,
               let resolved = connection.currentPath?.remoteEndpoint,
               case let .hostPort(host, port) = resolved {
                switch host {
                case let .ipv4(addr):
                    let ip = addr.debugDescription.components(separatedBy: "%").first ?? addr.debugDescription
                    logger.debug("🌐 Got IPv4: \(ip, privacy: .public)")
                    Task { @MainActor in
                        emitURL(scheme: scheme, ip: ip, port: port)
                        pendingResolutions.remove(serviceKey)
                    }

                case let .ipv6(addr):
                    let ip = addr.debugDescription.components(separatedBy: "%").first ?? addr.debugDescription

                    // Skip link-local and localhost IPv6 addresses
                    if !ip.hasPrefix("fe80:"), !ip.hasPrefix("::1"), !ip.hasPrefix("fc00:"), !ip.hasPrefix("fd") {
                        logger.debug("🌐 Got IPv6: \(ip, privacy: .public)")
                        Task { @MainActor in
                            emitURL(scheme: scheme, ip: "[\(ip)]", port: port) // IPv6 needs brackets in URLs
                            pendingResolutions.remove(serviceKey)
                        }
                    } else {
                        logger.debug("⚪ Skipped link-local IPv6: \(ip, privacy: .public)")
                        Task { @MainActor in
                            pendingResolutions.remove(serviceKey)
                        }
                    }

                case let .name(hostname, _):
                    logger.debug("🌐 Got hostname: \(hostname, privacy: .public)")

                    Task { @MainActor in
                        let addresses = resolveHostWithGetAddrInfo(hostname: hostname)
                        if addresses.isEmpty {
                            logger.warning("⚠️ Could not resolve hostname: \(hostname, privacy: .public)")
                        } else {
                            for ip in addresses {
                                emitURL(scheme: scheme, ip: ip, port: port)
                                let addressType = ip.contains(":") ? "IPv6" : "IPv4"
                                logger.notice("🔗 Resolved hostname to \(addressType): \(ip, privacy: .public)")
                            }
                            logger.info("🌐 Resolved hostname '\(hostname, privacy: .public)' to \(addresses.count) address(es)")
                        }
                        pendingResolutions.remove(serviceKey)
                    }

                default:
                    logger.debug("❌ Unsupported host: \(String(describing: host))")
                    Task { @MainActor in
                        pendingResolutions.remove(serviceKey)
                    }
                }

                connection.cancel()
            } else if case let .failed(error) = state {
                logger.warning("❌ Connection failed for \(serviceKey, privacy: .public): \(error.localizedDescription, privacy: .public)")
                Task { @MainActor in
                    pendingResolutions.remove(serviceKey)
                }
                connection.cancel()
            } else if case let .waiting(error) = state {
                logger.debug("⏳ Connection waiting for \(serviceKey, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        connection.start(queue: .main)
    }

    func resolveHostWithGetAddrInfo(hostname: String) -> [String] {
        var hints = addrinfo(
            ai_flags: AI_PASSIVE,
            ai_family: AF_UNSPEC, // Allow both IPv4 and IPv6
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )

        var res: UnsafeMutablePointer<addrinfo>?

        guard getaddrinfo(hostname, nil, &hints, &res) == 0 else { return [] }

        var result: [String] = []
        var ptr = res

        while ptr != nil {
            if let addr = ptr?.pointee.ai_addr {
                var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(ptr!.pointee.ai_addrlen), &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0 {
                    // Use recommended decoding: truncate at null terminator, then decode as UTF-8
                    if let endIndex = buffer.firstIndex(of: 0) {
                        let slice = buffer[..<endIndex].map { UInt8(bitPattern: $0) }
                        if let host = String(bytes: slice, encoding: .utf8) {
                            // Filter out link-local and localhost addresses
                            if !host.hasPrefix("fe80:"), !host.hasPrefix("127."), !host.hasPrefix("::1"),
                               !host.hasPrefix("fc00:"), !host.hasPrefix("fd") {
                                // Format IPv6 addresses with brackets for URL compatibility
                                if host.contains(":"), !host.hasPrefix("[") {
                                    result.append("[\(host)]")
                                } else {
                                    result.append(host)
                                }
                            }
                        }
                    } else {
                        // No null terminator found; attempt to decode entire buffer safely
                        let bytes = buffer.map { UInt8(bitPattern: $0) }
                        if let host = String(bytes: bytes, encoding: .utf8) {
                            // Trim any trailing control characters just in case
                            let cleanHost = host.trimmingCharacters(in: .controlCharacters)
                            // Filter out unwanted addresses
                            if !cleanHost.hasPrefix("fe80:"), !cleanHost.hasPrefix("127."), !cleanHost.hasPrefix("::1"),
                               !cleanHost.hasPrefix("fc00:"), !cleanHost.hasPrefix("fd") {
                                // Format IPv6 addresses with brackets for URL compatibility
                                if cleanHost.contains(":"), !cleanHost.hasPrefix("[") {
                                    result.append("[\(cleanHost)]")
                                } else {
                                    result.append(cleanHost)
                                }
                            }
                        }
                    }
                }
            }
            ptr = ptr?.pointee.ai_next
        }

        freeaddrinfo(res)
        return result
    }

    private func emitURL(scheme: String, ip: String, port: NWEndpoint.Port) {
        let portValue = UInt16(port.rawValue)
        let url = "\(scheme)://\(ip):\(portValue)"

        if !discoveredURLs.contains(url) {
            addDiscoveredUrl(url)
            logger.notice("🌍 Discovered server: \(url, privacy: .public)")

            // Group by server (inspired by flametouch AddressCluster approach)
            let serversOnSameIP = discoveredURLs.filter { existingURL in
                guard let existingHost = URL(string: existingURL)?.host,
                      let newHost = URL(string: url)?.host else { return false }
                return existingHost == newHost
            }

            if serversOnSameIP.count > 1 {
                let httpUrls = serversOnSameIP.filter { $0.hasPrefix("http://") }
                let httpsUrls = serversOnSameIP.filter { $0.hasPrefix("https://") }

                logger.info("🏠 Server cluster on IP \(ip, privacy: .public): HTTP=\(httpUrls.count), HTTPS=\(httpsUrls.count)")

                if !httpUrls.isEmpty, !httpsUrls.isEmpty {
                    logger.info("✅ Complete openHAB server found on \(ip, privacy: .public) (both HTTP & HTTPS)")
                }
            }
        } else {
            logger.debug("🔄 Duplicate URL ignored: \(url, privacy: .public)")
        }
    }
}
