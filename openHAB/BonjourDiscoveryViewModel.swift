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
class BonjourDiscoveryViewModel: ObservableObject {
    @Published public var discoveredURLs: [String] = []
    @Published public var isDiscovering = false

    private var browsers: [BonjourServiceType: NWBrowser] = [:]
    private var timeoutTasks: [BonjourServiceType: DispatchWorkItem] = [:]
    private let logger = Logger(subsystem: "org.openhab", category: "BonjourDiscovery")
    private let timeoutInterval: TimeInterval = 15

    public init() {}
}

extension BonjourDiscoveryViewModel {
    public func discoverAll() {
        discoverAllWithRetry(attempt: 1)
    }

    private func discoverAllWithRetry(attempt: Int, maxAttempts: Int = 2) {
        isDiscovering = true
        if attempt == 1 {
            discoveredURLs.removeAll()
        }
        stopAllDiscovery()

        var completedDiscoveries = 0
        let totalDiscoveries = 2
        let completionQueue = DispatchQueue.main

        let checkCompletion = {
            completionQueue.async {
                completedDiscoveries += 1
                self.logger.debug("Discovery completed: \(completedDiscoveries)/\(totalDiscoveries) (attempt \(attempt))")
                if completedDiscoveries >= totalDiscoveries {
                    let foundCount = self.discoveredURLs.count
                    let uniqueIPs = Set(self.discoveredURLs.compactMap { URL(string: $0)?.host }).count

                    if foundCount == 0, attempt < maxAttempts {
                        self.logger.info("🔄 No servers found on attempt \(attempt), retrying...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.discoverAllWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts)
                        }
                    } else {
                        self.isDiscovering = false
                        if foundCount > 0 {
                            self.logger.info("🎉 Discovery completed after \(attempt) attempt(s). Found \(foundCount) server(s) on \(uniqueIPs) IP(s)")
                            for url in self.discoveredURLs {
                                self.logger.info("  📍 \(url, privacy: .public)")
                            }
                        } else {
                            self.logger.info("🔍 Discovery completed after \(attempt) attempt(s). No openHAB servers found.")
                        }
                    }
                }
            }
        }

        logger.info("🔍 Starting parallel discovery (attempt \(attempt)/\(maxAttempts))")
        discover(using: .https, completion: checkCompletion)
        discover(using: .http, completion: checkCompletion)
    }

    public func discoverSequentially() {
        discoverAll()
    }

    private func discover(using serviceType: BonjourServiceType, completion: @escaping () -> Void) {
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
            DispatchQueue.main.async {
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
                logger.error("❌ NWBrowser failed: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async { completion() }
            default:
                break
            }
        }

        browser.start(queue: .main)

        // Timeout with individual tracking
        let timeoutTask = DispatchWorkItem { [weak self] in
            guard let self else { return }
            browsers[serviceType]?.cancel()
            browsers[serviceType] = nil
            timeoutTasks[serviceType] = nil
            logger.info("⏱️ Discovery for \(serviceType.rawValue, privacy: .public) completed.")
            completion()
        }

        timeoutTasks[serviceType] = timeoutTask
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutInterval, execute: timeoutTask)
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
    }

    private func resolve(endpoint: NWEndpoint, scheme: String) {
        guard case let .service(name, type, domain, _) = endpoint else {
            logger.debug("❌ Not a service endpoint: \(String(describing: endpoint))")
            return
        }

        logger.debug("🔍 Resolving \(scheme, privacy: .public) service: \(name, privacy: .public) (\(type, privacy: .public))")
        let serviceEndpoint = NWEndpoint.service(name: name, type: type, domain: domain, interface: nil)

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        let connection = NWConnection(to: serviceEndpoint, using: parameters)

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }

            if case .ready = state,
               let resolved = connection.currentPath?.remoteEndpoint,
               case let .hostPort(host, port) = resolved {
                switch host {
                case let .ipv4(addr):
                    let ip = addr.debugDescription.components(separatedBy: "%").first ?? addr.debugDescription
                    logger.debug("🌐 Got ipv4: \(ip, privacy: .public)")
                    emitURL(scheme: scheme, ip: ip, port: port)

                case let .name(hostname, _):
                    logger.debug("🌐 Got hostname: \(hostname, privacy: .public)")

                    let addresses = resolveHostWithGetAddrInfo(hostname: hostname)
                    if let ip = addresses.first {
                        emitURL(scheme: scheme, ip: ip, port: port)
                        logger.notice("🔗 Resolved hostname to IPv4: \(ip, privacy: .public)")
                    } else {
                        logger.warning("⚠️ Could not resolve hostname: \(hostname, privacy: .public)")
                    }

                default:
                    logger.debug("❌ Unsupported host: \(String(describing: host))")
                }

                connection.cancel()
            }
        }

        connection.start(queue: .main)
    }

    func resolveHostWithGetAddrInfo(hostname: String) -> [String] {
        var hints = addrinfo(
            ai_flags: AI_PASSIVE,
            ai_family: AF_INET,
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
                    result.append(String(cString: buffer))
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

        DispatchQueue.main.async {
            if !self.discoveredURLs.contains(url) {
                self.discoveredURLs.append(url)
                self.logger.notice("🌍 Discovered server: \(url, privacy: .public)")

                // Check for multiple servers on same IP
                let existingOnSameIP = self.discoveredURLs.filter { existingURL in
                    guard let existingHost = URL(string: existingURL)?.host,
                          let newHost = URL(string: url)?.host else { return false }
                    return existingHost == newHost && existingURL != url
                }

                if !existingOnSameIP.isEmpty {
                    self.logger.info("🏠 Multiple servers found on IP \(ip, privacy: .public): \(existingOnSameIP.count + 1) total")
                }
            } else {
                self.logger.debug("🔄 Duplicate URL ignored: \(url, privacy: .public)")
            }
        }
    }
}
