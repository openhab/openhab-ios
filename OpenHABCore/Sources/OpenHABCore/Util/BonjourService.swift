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

// MARK: - Public Types

public enum BonjourServiceType: String, CaseIterable, Sendable {
    case https = "_openhab-server-ssl._tcp."
    case http = "_openhab-server._tcp."

    public var scheme: String {
        switch self {
        case .https: "https"
        case .http: "http"
        }
    }
}

public struct DiscoveredServer: Hashable, Sendable {
    public let scheme: String
    public let address: String
    public let port: Int

    public var url: String { "\(scheme)://\(address):\(port)" }

    public init(scheme: String, address: String, port: Int) {
        self.scheme = scheme
        self.address = address
        self.port = port
    }
}

// MARK: - Bonjour Service

#if !os(watchOS)
/// A reusable Bonjour discovery service that finds openHAB servers on the local network.
/// Thread-safe and works on both iOS and macOS.
/// Note: Not available on watchOS (NetServiceBrowser is unavailable).
public final class BonjourService: NSObject, NetServiceBrowserDelegate, NetServiceDelegate, @unchecked Sendable {
    // MARK: - Types

    private struct SchemePort: Hashable {
        let scheme: String
        let port: Int
    }

    private struct ServiceAddressKey: Hashable {
        let name: String
        let type: String
    }

    // MARK: - Properties

    private let logger = Logger(subsystem: "org.openhab", category: "BonjourService")
    private var browsers: [BonjourServiceType: NetServiceBrowser] = [:]
    private var discoveredServices: [NetService] = []
    private var additionalAddresses: [ServiceAddressKey: [String]] = [:]

    // Accumulated results across cycles
    private var allDiscoveredAddresses: Set<String> = []
    private var allDiscoveredSchemePorts: Set<SchemePort> = []

    // Threading
    private var thread: Thread?
    private var runLoop: RunLoop?
    private let isRunning = OSAllocatedUnfairLock(initialState: false)

    // Callback
    private var onUpdate: (([DiscoveredServer]) -> Void)?

    // MARK: - Public API

    override public init() {
        super.init()
    }

    /// Start discovery with the given configuration.
    /// - Parameters:
    ///   - cycles: Number of discovery cycles (helps find multi-homed servers)
    ///   - cycleDuration: Duration of each cycle in seconds
    ///   - onUpdate: Called when servers are discovered (may be called multiple times)
    ///   - onComplete: Called when all cycles are finished
    public func start(cycles: Int = 1,
                      cycleDuration: TimeInterval = 10,
                      onUpdate: @escaping ([DiscoveredServer]) -> Void,
                      onComplete: (() -> Void)? = nil) {
        self.onUpdate = onUpdate

        logger.info("Starting Bonjour discovery (cycles: \(cycles), duration: \(cycleDuration)s)")

        // Reset accumulated results
        allDiscoveredAddresses.removeAll()
        allDiscoveredSchemePorts.removeAll()

        isRunning.withLock { $0 = true }

        thread = Thread { [weak self] in
            guard let self else { return }
            runLoop = RunLoop.current

            // Add dummy source to keep runloop alive
            runLoop?.add(NSMachPort(), forMode: .default)

            for cycle in 1 ... cycles {
                guard isRunning.withLock({ $0 }) else { break }

                logger.debug("Starting cycle \(cycle)/\(cycles)")
                startBrowsers()

                // Run for the cycle duration
                let endTime = Date(timeIntervalSinceNow: cycleDuration)
                while isRunning.withLock({ $0 }), Date() < endTime {
                    runLoop?.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
                }

                stopBrowsers()
                let addrCount = allDiscoveredAddresses.count
                logger.debug("Cycle \(cycle) complete. Addresses: \(addrCount)")
            }

            let finalCount = allDiscoveredAddresses.count
            logger.info("Discovery complete. Found \(finalCount) address(es)")

            // Final broadcast with all accumulated results
            broadcastAll()

            DispatchQueue.main.async {
                onComplete?()
            }
        }
        thread?.name = "BonjourDiscovery"
        thread?.start()
    }

    /// Stop discovery immediately.
    public func stop() {
        logger.debug("Stopping discovery")
        isRunning.withLock { $0 = false }

        if let runLoop {
            CFRunLoopPerformBlock(runLoop.getCFRunLoop(), CFRunLoopMode.defaultMode.rawValue) { [weak self] in
                self?.stopBrowsers()
                self?.discoveredServices.removeAll()
                self?.additionalAddresses.removeAll()
            }
            CFRunLoopWakeUp(runLoop.getCFRunLoop())
        }
    }

    /// Get all currently discovered servers (cross-combined addresses × endpoints).
    public func getDiscoveredServers() -> [DiscoveredServer] {
        var servers: [DiscoveredServer] = []
        for address in allDiscoveredAddresses.sorted() {
            for sp in allDiscoveredSchemePorts.sorted(by: { $0.scheme < $1.scheme || ($0.scheme == $1.scheme && $0.port < $1.port) }) {
                servers.append(DiscoveredServer(scheme: sp.scheme, address: address, port: sp.port))
            }
        }
        return servers
    }

    // MARK: - Private Methods

    private func startBrowsers() {
        // Clear per-cycle state but keep accumulated addresses
        discoveredServices.removeAll()
        additionalAddresses.removeAll()

        for serviceType in BonjourServiceType.allCases {
            let browser = NetServiceBrowser()
            browser.delegate = self
            browsers[serviceType] = browser
            browser.searchForServices(ofType: serviceType.rawValue, inDomain: "local.")
            logger.debug("Searching for \(serviceType.rawValue, privacy: .public)")
        }
    }

    private func stopBrowsers() {
        for browser in browsers.values {
            browser.stop()
        }
        browsers.removeAll()

        for service in discoveredServices {
            service.stop()
        }
    }

    private func broadcast() {
        // Collect addresses from current cycle's services
        var cycleAddresses: Set<String> = []
        var cycleSchemePorts: Set<SchemePort> = []

        for service in discoveredServices {
            let scheme = schemeForServiceType(service.type)
            let port = service.port
            let addressKey = ServiceAddressKey(name: service.name, type: service.type)

            guard port > 0 else { continue }

            cycleSchemePorts.insert(SchemePort(scheme: scheme, port: port))

            // Addresses from NetService
            if let addresses = service.addresses {
                for addressData in addresses {
                    if let address = extractAddress(from: addressData) {
                        cycleAddresses.insert(address)
                    }
                }
            }

            // Addresses from DNS lookups
            if let dnsAddresses = additionalAddresses[addressKey] {
                for address in dnsAddresses {
                    var formattedAddress = address
                    if address.contains(":"), !address.hasPrefix("[") {
                        formattedAddress = "[\(address)]"
                    }
                    cycleAddresses.insert(formattedAddress)
                }
            }
        }

        // Accumulate across cycles
        allDiscoveredAddresses.formUnion(cycleAddresses)
        allDiscoveredSchemePorts.formUnion(cycleSchemePorts)

        // Build cross-combined servers
        let servers = getDiscoveredServers()

        let addressCount = allDiscoveredAddresses.count
        logger.info("Broadcasting \(servers.count) server(s) from \(addressCount) address(es)")

        // Notify on main thread
        if let onUpdate {
            DispatchQueue.main.sync {
                onUpdate(servers)
            }
        }
    }

    private func broadcastAll() {
        let servers = getDiscoveredServers()

        if let onUpdate {
            DispatchQueue.main.sync {
                onUpdate(servers)
            }
        }
    }

    private func schemeForServiceType(_ type: String) -> String {
        type.contains("ssl") ? "https" : "http"
    }

    // MARK: - NetServiceBrowserDelegate

    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        logger.info("Found service: \(service.name, privacy: .public) type: \(service.type, privacy: .public)")

        if discoveredServices.contains(where: { $0 === service }) {
            return
        }

        discoveredServices.append(service)
        service.delegate = self
        service.startMonitoring()
        service.resolve(withTimeout: 10)
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        logger.debug("Service removed: \(service.name, privacy: .public)")
        discoveredServices.removeAll { $0.name == service.name && $0.type == service.type }
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        logger.error("Browser failed to search: \(errorDict)")
    }

    // MARK: - NetServiceDelegate

    public func netServiceDidResolveAddress(_ sender: NetService) {
        logger.info("Resolved: \(sender.name, privacy: .public) hostname: \(sender.hostName ?? "nil", privacy: .public) port: \(sender.port)")

        if let addresses = sender.addresses {
            for (index, data) in addresses.enumerated() {
                if let addr = extractAddress(from: data) {
                    logger.debug("  address[\(index)]: \(addr, privacy: .public)")
                }
            }
        }

        // DNS lookup for hostname
        if let hostname = sender.hostName {
            resolveHostname(hostname, forService: sender)
        }

        // Try alternate hostname
        let alternateHostname = "\(sender.name).local."
        if alternateHostname != sender.hostName {
            resolveHostname(alternateHostname, forService: sender)
        }

        broadcast()
    }

    public func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        logger.warning("Failed to resolve \(sender.name, privacy: .public): \(errorDict)")
    }

    public func netServiceDidStop(_ sender: NetService) {
        logger.debug("Service stopped: \(sender.name, privacy: .public)")
    }

    // MARK: - Address Resolution

    private func resolveHostname(_ hostname: String, forService service: NetService) {
        let cleanHostname = hostname.hasSuffix(".") ? String(hostname.dropLast()) : hostname

        logger.debug("DNS lookup for \(cleanHostname, privacy: .public)")

        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM

        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(cleanHostname, nil, &hints, &result)

        if status != 0 {
            if let errorString = gai_strerror(status) {
                logger.debug("  DNS lookup failed: \(String(cString: errorString), privacy: .public)")
            }
            return
        }

        defer { freeaddrinfo(result) }

        var current = result
        while let info = current {
            if let sockaddr = info.pointee.ai_addr {
                var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let addrLen = socklen_t(info.pointee.ai_addrlen)

                if getnameinfo(sockaddr, addrLen, &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST) == 0 {
                    var address = stringFromCCharArray(hostBuffer)

                    if let percentIndex = address.firstIndex(of: "%") {
                        address = String(address[..<percentIndex])
                    }

                    if !address.hasPrefix("fe80:"),
                       !address.hasPrefix("127."),
                       address != "::1",
                       !address.hasPrefix("fc"),
                       !address.hasPrefix("fd") {
                        logger.debug("  DNS resolved: \(address, privacy: .public)")

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

        if let percentIndex = address.firstIndex(of: "%") {
            address = String(address[..<percentIndex])
        }

        // Filter unwanted addresses
        if address.hasPrefix("fe80:") ||
            address.hasPrefix("127.") ||
            address == "::1" ||
            address.hasPrefix("fc") ||
            address.hasPrefix("fd") {
            return nil
        }

        // Format IPv6 with brackets
        if address.contains(":"), !address.hasPrefix("[") {
            return "[\(address)]"
        }
        return address
    }

    private func stringFromCCharArray(_ chars: [CChar]) -> String {
        chars.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return "" }
            return String(cString: baseAddress)
        }
    }
}
#endif
