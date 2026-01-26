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
import os

enum BonjourServiceType: String, CaseIterable {
    case https = "_openhab-server-ssl._tcp."
    case http = "_openhab-server._tcp."

    var scheme: String {
        switch self {
        case .https: "https"
        case .http: "http"
        }
    }
}

// MARK: - NetServiceBrowser-based Discovery (like flametouch)

/// Handles Bonjour service discovery using NetServiceBrowser on a dedicated background thread
/// (like flametouch - NetServiceBrowser needs its own RunLoop and address resolution can block)
/// Thread-safety: All mutable state is accessed on the dedicated background thread via the RunLoop.
private final class ServiceBrowserDelegate: NSObject, NetServiceBrowserDelegate, NetServiceDelegate, @unchecked Sendable {
    // Track additional addresses discovered via DNS lookup (since we can't modify NetService.addresses)
    private struct ServiceAddressKey: Hashable {
        let name: String
        let type: String
    }

    struct DiscoveredServer: Hashable {
        let scheme: String
        let address: String
        let port: Int

        var url: String { "\(scheme)://\(address):\(port)" }
    }

    private struct SchemePort: Hashable {
        let scheme: String
        let port: Int
    }

    private let logger = Logger(subsystem: "org.openhab", category: "ServiceBrowser")
    private var browsers: [BonjourServiceType: NetServiceBrowser] = [:]
    private var discoveredServices: [NetService] = []
    private let onUpdate: @Sendable ([DiscoveredServer]) -> Void

    private var additionalAddresses: [ServiceAddressKey: [String]] = [:]

    // Dedicated thread with RunLoop for NetServiceBrowser (like flametouch)
    private var thread: Thread?
    private var runLoop: RunLoop?
    private var isRunning = false

    init(onUpdate: @escaping @Sendable ([DiscoveredServer]) -> Void) {
        self.onUpdate = onUpdate
        super.init()
    }

    func start() {
        logger.info("🔍 Starting NetServiceBrowser discovery on background thread")
        isRunning = true

        // Create dedicated thread with RunLoop (like flametouch)
        // Start browsers directly in the thread entry point to avoid priority inversion
        thread = Thread { [weak self] in
            guard let self else { return }
            runLoop = RunLoop.current

            // Add dummy source to keep runloop alive
            runLoop?.add(NSMachPort(), forMode: .default)

            // Start browsers immediately on this thread (they'll use this RunLoop)
            for serviceType in BonjourServiceType.allCases {
                let browser = NetServiceBrowser()
                browser.delegate = self
                browsers[serviceType] = browser
                browser.searchForServices(ofType: serviceType.rawValue, inDomain: "local.")
                logger.info("🔍 Searching for \(serviceType.rawValue, privacy: .public) in local.")
            }

            logger.debug("🔄 RunLoop started on background thread")

            // Run the loop
            while isRunning, let runLoop {
                let didProcess = runLoop.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
                if !didProcess {
                    Thread.sleep(forTimeInterval: 0.01)
                }
            }
            logger.debug("🔄 RunLoop ended")
        }
        thread?.name = "BonjourDiscovery"
        thread?.start()
    }

    func stop() {
        logger.debug("🛑 Stopping discovery")

        // Signal the run loop to stop
        isRunning = false

        // Stop browsers and services on the background thread
        if let runLoop {
            CFRunLoopPerformBlock(runLoop.getCFRunLoop(), CFRunLoopMode.defaultMode.rawValue) { [weak self] in
                guard let self else { return }
                for browser in browsers.values {
                    browser.stop()
                }
                browsers.removeAll()

                for service in discoveredServices {
                    service.stop()
                }
                discoveredServices.removeAll()
                additionalAddresses.removeAll()
            }
            CFRunLoopWakeUp(runLoop.getCFRunLoop())
        }

        runLoop = nil
        thread = nil
    }

    private func performOnThread(_ block: @escaping () -> Void) {
        guard let runLoop else {
            block()
            return
        }
        CFRunLoopPerformBlock(runLoop.getCFRunLoop(), CFRunLoopMode.defaultMode.rawValue, block)
        CFRunLoopWakeUp(runLoop.getCFRunLoop())
    }

    // MARK: - NetServiceBrowserDelegate

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        logger.info("🟡 Found service: \(service.name, privacy: .public) type: \(service.type, privacy: .public) domain: \(service.domain, privacy: .public) hostName: \(service.hostName ?? "nil", privacy: .public)")

        // Check if we already have this exact service instance (by identity)
        // Allow multiple discoveries of the same name if they're different NetService objects
        // (which may happen when the same service is discovered via different interfaces)
        if discoveredServices.contains(where: { $0 === service }) {
            logger.debug("  ↳ Skipping (already tracking this instance)")
            return
        }

        // Check if we have a service with the same name but a different hostname
        // This can happen with multi-homed hosts advertising on multiple interfaces
        let existingWithSameName = discoveredServices.first { $0.name == service.name && $0.type == service.type }
        if let existing = existingWithSameName {
            logger.info("  ↳ Found another instance of \(service.name, privacy: .public) (existing hostName: \(existing.hostName ?? "nil", privacy: .public))")
        }

        discoveredServices.append(service)
        service.delegate = self

        // startMonitoring keeps getting address updates (critical for multi-homed hosts)
        service.startMonitoring()
        // resolve gets the initial addresses
        service.resolve(withTimeout: 10)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        logger.debug("🔴 Service removed: \(service.name, privacy: .public)")
        discoveredServices.removeAll { $0.name == service.name && $0.type == service.type }
        broadcast()
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        logger.error("❌ Browser failed to search: \(errorDict)")
    }

    // MARK: - NetServiceDelegate

    func netServiceDidResolveAddress(_ sender: NetService) {
        logger.info("🟢 Resolved: \(sender.name, privacy: .public) hostName: \(sender.hostName ?? "nil", privacy: .public) port: \(sender.port) addresses: \(sender.addresses?.count ?? 0)")
        if let addresses = sender.addresses {
            for (index, data) in addresses.enumerated() {
                if let addr = extractAddress(from: data) {
                    logger.info("  ↳ address[\(index)]: \(addr, privacy: .public)")
                } else {
                    logger.debug("  ↳ address[\(index)]: (filtered out)")
                }
            }
        }

        // Also try resolving the service name as a hostname (e.g., "openhab.local.")
        // This might return additional addresses that aren't in the service record
        if let hostname = sender.hostName {
            resolveHostname(hostname, forService: sender)
        }

        // Additionally, try resolving "<servicename>.local." as some servers advertise there
        let alternateHostname = "\(sender.name).local."
        if alternateHostname != sender.hostName {
            resolveHostname(alternateHostname, forService: sender)
        }

        broadcast()
    }

    /// Resolve a hostname using getaddrinfo to potentially get multiple IP addresses
    private func resolveHostname(_ hostname: String, forService service: NetService) {
        // Remove trailing dot if present for getaddrinfo
        let cleanHostname = hostname.hasSuffix(".") ? String(hostname.dropLast()) : hostname

        logger.debug("🔎 Attempting DNS lookup for \(cleanHostname, privacy: .public)")

        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC // Both IPv4 and IPv6
        hints.ai_socktype = SOCK_STREAM

        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(cleanHostname, nil, &hints, &result)

        if status != 0 {
            if let errorString = gai_strerror(status) {
                logger.debug("  ↳ DNS lookup failed: \(String(cString: errorString), privacy: .public)")
            }
            return
        }

        defer { freeaddrinfo(result) }

        var addressCount = 0
        var current = result
        while let info = current {
            addressCount += 1
            if let sockaddr = info.pointee.ai_addr {
                var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let addrLen = socklen_t(info.pointee.ai_addrlen)

                if getnameinfo(sockaddr, addrLen, &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST) == 0 {
                    var address = stringFromCCharArray(hostBuffer)

                    // Remove scope ID for IPv6
                    if let percentIndex = address.firstIndex(of: "%") {
                        address = String(address[..<percentIndex])
                    }

                    // Skip filtered addresses
                    if !address.hasPrefix("fe80:"),
                       !address.hasPrefix("127."),
                       address != "::1",
                       !address.hasPrefix("fc00:"),
                       !address.hasPrefix("fd") {
                        logger.info("  ↳ DNS resolved: \(address, privacy: .public)")

                        // Add this address to the service's address list if not already present
                        // (we track additional addresses separately since we can't modify NetService.addresses)
                        let key = ServiceAddressKey(name: service.name, type: service.type)
                        if additionalAddresses[key] == nil {
                            additionalAddresses[key] = []
                        }
                        if !additionalAddresses[key]!.contains(address) {
                            additionalAddresses[key]!.append(address)
                        }
                    }
                }
            }
            current = info.pointee.ai_next
        }

        logger.debug("  ↳ DNS lookup found \(addressCount) address(es)")
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        logger.warning("❌ Failed to resolve \(sender.name, privacy: .public): \(errorDict)")
    }

    func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {
        logger.debug("📝 TXT updated for \(sender.name, privacy: .public)")
    }

    // Called when startMonitoring() receives address updates
    func netServiceDidStop(_ sender: NetService) {
        logger.debug("🛑 Service stopped: \(sender.name, privacy: .public)")
    }

    // MARK: - Address extraction

    private func broadcast() {
        // Collect all unique addresses and all unique scheme+port combinations
        var allAddresses: Set<String> = []
        var allEndpoints: Set<SchemePort> = []

        for service in discoveredServices {
            let scheme = schemeForServiceType(service.type)
            let port = service.port
            let addressKey = ServiceAddressKey(name: service.name, type: service.type)

            // Only consider services with valid ports
            guard port > 0 else { continue }

            // Add this scheme+port combination
            allEndpoints.insert(SchemePort(scheme: scheme, port: port))

            // Collect addresses from NetService resolution
            if let addresses = service.addresses {
                logger.debug("📋 Service \(service.name, privacy: .public) has \(addresses.count) raw addresses from NetService")
                for addressData in addresses {
                    if let address = extractAddress(from: addressData) {
                        allAddresses.insert(address)
                    }
                }
            }

            // Collect addresses from DNS lookups
            if let dnsAddresses = additionalAddresses[addressKey] {
                logger.debug("📋 Service \(service.name, privacy: .public) has \(dnsAddresses.count) addresses from DNS lookup")
                for address in dnsAddresses {
                    // Format IPv6 addresses with brackets
                    var formattedAddress = address
                    if address.contains(":"), !address.hasPrefix("[") {
                        formattedAddress = "[\(address)]"
                    }
                    allAddresses.insert(formattedAddress)
                }
            }
        }

        logger.info("📋 Cross-combining \(allAddresses.count) unique addresses with \(allEndpoints.count) endpoints")

        // Cross-combine all addresses with all scheme+port combinations
        // This handles multi-homed servers where different services are advertised on different interfaces
        var servers: [DiscoveredServer] = []

        for address in allAddresses.sorted() {
            for endpoint in allEndpoints.sorted(by: { $0.scheme < $1.scheme || ($0.scheme == $1.scheme && $0.port < $1.port) }) {
                let server = DiscoveredServer(scheme: endpoint.scheme, address: address, port: endpoint.port)
                servers.append(server)
                logger.debug("  ✅ \(endpoint.scheme, privacy: .public)://\(address, privacy: .public):\(endpoint.port)")
            }
        }

        onUpdate(servers)
    }

    private func schemeForServiceType(_ type: String) -> String {
        if type.contains("ssl") {
            return "https"
        }
        return "http"
    }

    private func extractAddress(from data: Data) -> String? {
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))

        let result = data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> Int32 in
            guard let sockaddr = pointer.baseAddress?.assumingMemoryBound(to: sockaddr.self) else {
                return -1
            }
            return getnameinfo(
                sockaddr,
                socklen_t(data.count),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
        }

        guard result == 0 else { return nil }

        var address = stringFromCCharArray(hostname)

        // Remove scope ID suffix for IPv6 (e.g., "fe80::1%en0" -> "fe80::1")
        if let percentIndex = address.firstIndex(of: "%") {
            address = String(address[..<percentIndex])
        }

        // Filter out link-local and localhost addresses
        if address.hasPrefix("fe80:") ||
            address.hasPrefix("127.") ||
            address == "::1" ||
            address.hasPrefix("fc00:") ||
            address.hasPrefix("fd") {
            return nil
        }

        // Format IPv6 addresses with brackets for URL compatibility
        if address.contains(":"), !address.hasPrefix("[") {
            return "[\(address)]"
        }
        return address
    }

    /// Convert a null-terminated CChar array to String using pointer-based API (not deprecated)
    private func stringFromCCharArray(_ chars: [CChar]) -> String {
        chars.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return "" }
            return String(cString: baseAddress)
        }
    }
}

// MARK: - ViewModel

@MainActor
final class BonjourDiscoveryViewModel: ObservableObject {
    @Published var discoveredURLs: [String] = []
    @Published var isDiscovering = false

    private var browserDelegate: ServiceBrowserDelegate?
    private var completionTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "org.openhab", category: "BonjourDiscovery")
    private let discoveryDuration: TimeInterval = 10

    init() {}

    func discoverAll() {
        isDiscovering = true
        discoveredURLs.removeAll()

        logger.info("🔍 Starting Bonjour discovery")

        // Create browser delegate on main thread (NetServiceBrowser uses current RunLoop)
        browserDelegate = ServiceBrowserDelegate { [weak self] servers in
            Task { @MainActor in
                self?.handleDiscoveredServers(servers)
            }
        }

        browserDelegate?.start()

        // Run discovery for a fixed duration then stop
        completionTask = Task {
            try? await Task.sleep(for: .seconds(discoveryDuration))
            completeDiscovery()
        }
    }

    private func handleDiscoveredServers(_ servers: [ServiceBrowserDelegate.DiscoveredServer]) {
        for server in servers where !discoveredURLs.contains(server.url) {
            discoveredURLs.append(server.url)
            logger.notice("🌍 Discovered: \(server.url, privacy: .public)")
        }
    }

    private func completeDiscovery() {
        browserDelegate?.stop()
        browserDelegate = nil
        isDiscovering = false

        let urls = discoveredURLs
        let uniqueIPs = Set(urls.compactMap { URL(string: $0)?.host }).count
        logger.info("🎉 Discovery completed. Found \(urls.count) server(s) on \(uniqueIPs) IP(s)")
        for url in urls {
            logger.info("  📍 \(url, privacy: .public)")
        }
    }

    func resetDiscoveredUrls() {
        completionTask?.cancel()
        browserDelegate?.stop()
        browserDelegate = nil
        discoveredURLs.removeAll()
        isDiscovering = false
    }
}
