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

    public var url: String {
        "\(scheme)://\(address):\(port)"
    }

    public init(scheme: String, address: String, port: Int) {
        self.scheme = scheme
        self.address = address
        self.port = port
    }
}

// MARK: - Address Utilities

enum BonjourAddressUtils {
    /// Determines if an address should be filtered out (link-local, loopback, unique local)
    static func shouldFilterAddress(_ address: String) -> Bool {
        address.hasPrefix("fe80:") ||
            address.hasPrefix("127.") ||
            address == "::1" ||
            address.hasPrefix("fc") ||
            address.hasPrefix("fd")
    }

    /// Strips zone ID suffix from IPv6 addresses (e.g., "fe80::1%en0" -> "fe80::1")
    static func stripZoneID(from address: String) -> String {
        if let percentIndex = address.firstIndex(of: "%") {
            return String(address[..<percentIndex])
        }
        return address
    }

    /// Formats an IPv6 address with brackets for URL usage
    static func formatForURL(_ address: String) -> String {
        if address.contains(":"), !address.hasPrefix("[") {
            return "[\(address)]"
        }
        return address
    }
}

// MARK: - Bonjour Service Protocol

#if !os(watchOS)
/// Protocol for Bonjour discovery services, enabling dependency injection and testing.
public protocol BonjourServiceProtocol: AnyObject, Sendable {
    func start(cycles: Int,
               cycleDuration: TimeInterval,
               onUpdate: @escaping @Sendable ([DiscoveredServer]) -> Void,
               onComplete: (@Sendable () -> Void)?)
    func stop()
    func getDiscoveredServers() -> [DiscoveredServer]
}

// MARK: - Bonjour Service

/// A reusable Bonjour discovery service that finds openHAB servers on the local network.
/// Thread-safe and works on both iOS and macOS.
/// Note: Not available on watchOS (NetServiceBrowser is unavailable).
///
/// ## Thread Safety
///
/// This class uses a dedicated thread with its own RunLoop for NetService operations
/// (required by the NetService API). All mutable state is protected by an unfair lock
/// to ensure thread-safe access from:
/// - The main thread (via `start()`, `stop()`, `getDiscoveredServers()`)
/// - The discovery thread (via delegate callbacks)
///
/// The class is marked `Sendable` and all cross-thread state access goes through
/// `state.withLockUnchecked { ... }`.
public final class BonjourService: NSObject, BonjourServiceProtocol, NetServiceBrowserDelegate, NetServiceDelegate, Sendable {
    // MARK: - Types

    private struct SchemePort: Hashable {
        let scheme: String
        let port: Int
    }

    private struct ServiceAddressKey: Hashable {
        let name: String
        let type: String
    }

    /// Container for all mutable state.
    ///
    /// Safety invariant: This struct is marked `@unchecked Sendable` because:
    /// 1. It contains non-Sendable Foundation types (NetServiceBrowser, NetService, Thread, RunLoop)
    /// 2. Thread-safety is guaranteed by the enclosing `OSAllocatedUnfairLock`
    /// 3. All access to State properties goes through `state.withLockUnchecked { ... }`
    private struct State: @unchecked Sendable {
        var browsers: [BonjourServiceType: NetServiceBrowser] = [:]
        var discoveredServices: [NetService] = []
        var additionalAddresses: [ServiceAddressKey: [String]] = [:]
        var allDiscoveredAddresses: Set<String> = []
        var allDiscoveredSchemePorts: Set<SchemePort> = []
        var thread: Thread?
        var runLoop: RunLoop?
        var isRunning = false
        var onUpdate: (@Sendable ([DiscoveredServer]) -> Void)?
    }

    // MARK: - Properties

    private let logger = Logger(subsystem: "org.openhab", category: "BonjourService")

    /// All mutable state is protected by this lock for thread-safe access.
    private let state = OSAllocatedUnfairLock(initialState: State())

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
                      onUpdate: @escaping @Sendable ([DiscoveredServer]) -> Void,
                      onComplete: (@Sendable () -> Void)? = nil) {
        state.withLockUnchecked { state in
            state.onUpdate = onUpdate
            state.allDiscoveredAddresses.removeAll()
            state.allDiscoveredSchemePorts.removeAll()
            state.isRunning = true
        }

        logger.info("Starting Bonjour discovery (cycles: \(cycles), duration: \(cycleDuration)s)")

        let newThread = Thread { [weak self] in
            guard let self else { return }

            let currentRunLoop = RunLoop.current
            state.withLockUnchecked { $0.runLoop = currentRunLoop }

            // Add dummy source to keep runloop alive
            currentRunLoop.add(NSMachPort(), forMode: .default)

            for cycle in 1 ... cycles {
                guard state.withLockUnchecked({ $0.isRunning }) else { break }

                logger.debug("Starting cycle \(cycle)/\(cycles)")
                startBrowsers()

                // Run for the cycle duration
                let endTime = Date(timeIntervalSinceNow: cycleDuration)
                while state.withLockUnchecked({ $0.isRunning }), Date() < endTime {
                    currentRunLoop.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
                }

                stopBrowsers()
                let addrCount = state.withLockUnchecked { $0.allDiscoveredAddresses.count }
                logger.debug("Cycle \(cycle) complete. Addresses: \(addrCount)")
            }

            let finalCount = state.withLockUnchecked { $0.allDiscoveredAddresses.count }
            logger.info("Discovery complete. Found \(finalCount) address(es)")

            // Final broadcast with all accumulated results
            broadcastAll()

            DispatchQueue.main.async {
                onComplete?()
            }
        }
        newThread.name = "BonjourDiscovery"
        state.withLockUnchecked { $0.thread = newThread }
        newThread.start()
    }

    /// Stop discovery immediately.
    public func stop() {
        logger.debug("Stopping discovery")

        let currentRunLoop = state.withLockUnchecked { state -> RunLoop? in
            state.isRunning = false
            state.onUpdate = nil
            return state.runLoop
        }

        if let currentRunLoop {
            CFRunLoopPerformBlock(currentRunLoop.getCFRunLoop(), CFRunLoopMode.defaultMode.rawValue) { [weak self] in
                self?.stopBrowsers()
                self?.state.withLockUnchecked { state in
                    state.discoveredServices.removeAll()
                    state.additionalAddresses.removeAll()
                }
            }
            CFRunLoopWakeUp(currentRunLoop.getCFRunLoop())
        }
    }

    /// Get all currently discovered servers (cross-combined addresses × endpoints).
    public func getDiscoveredServers() -> [DiscoveredServer] {
        state.withLockUnchecked { state in
            var servers: [DiscoveredServer] = []
            let sortedAddresses = state.allDiscoveredAddresses.sorted()
            let sortedSchemePorts = state.allDiscoveredSchemePorts.sorted { lhs, rhs in
                if lhs.scheme != rhs.scheme {
                    return lhs.scheme < rhs.scheme
                }
                return lhs.port < rhs.port
            }
            for address in sortedAddresses {
                for sp in sortedSchemePorts {
                    servers.append(DiscoveredServer(scheme: sp.scheme, address: address, port: sp.port))
                }
            }
            return servers
        }
    }

    // MARK: - Private Methods

    private func startBrowsers() {
        // Clear per-cycle state but keep accumulated addresses
        state.withLockUnchecked { state in
            state.discoveredServices.removeAll()
            state.additionalAddresses.removeAll()
        }

        for serviceType in BonjourServiceType.allCases {
            let browser = NetServiceBrowser()
            browser.delegate = self
            state.withLockUnchecked { $0.browsers[serviceType] = browser }
            browser.searchForServices(ofType: serviceType.rawValue, inDomain: "local.")
            logger.debug("Searching for \(serviceType.rawValue, privacy: .public)")
        }
    }

    private func stopBrowsers() {
        let (browsers, services) = state.withLockUnchecked { state -> ([NetServiceBrowser], [NetService]) in
            let browsers = Array(state.browsers.values)
            let services = state.discoveredServices
            state.browsers.removeAll()
            return (browsers, services)
        }

        for browser in browsers {
            browser.stop()
        }

        for service in services {
            service.stop()
        }
    }

    private func broadcast() {
        // Collect addresses from current cycle's services
        var cycleAddresses: Set<String> = []
        var cycleSchemePorts: Set<SchemePort> = []

        let (services, additionalAddrs) = state.withLockUnchecked { state in
            (state.discoveredServices, state.additionalAddresses)
        }

        for service in services {
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
            if let dnsAddresses = additionalAddrs[addressKey] {
                for address in dnsAddresses {
                    cycleAddresses.insert(BonjourAddressUtils.formatForURL(address))
                }
            }
        }

        // Accumulate across cycles and get callback
        let onUpdateCallback = state.withLockUnchecked { state -> (@Sendable ([DiscoveredServer]) -> Void)? in
            state.allDiscoveredAddresses.formUnion(cycleAddresses)
            state.allDiscoveredSchemePorts.formUnion(cycleSchemePorts)
            return state.onUpdate
        }

        // Build cross-combined servers
        let servers = getDiscoveredServers()

        let addressCount = state.withLockUnchecked { $0.allDiscoveredAddresses.count }
        logger.info("Broadcasting \(servers.count) server(s) from \(addressCount) address(es)")

        // Notify on main thread
        if let onUpdateCallback {
            DispatchQueue.main.async {
                onUpdateCallback(servers)
            }
        }
    }

    private func broadcastAll() {
        let servers = getDiscoveredServers()

        let onUpdateCallback = state.withLockUnchecked { $0.onUpdate }
        if let onUpdateCallback {
            DispatchQueue.main.async {
                onUpdateCallback(servers)
            }
        }
    }

    private func schemeForServiceType(_ type: String) -> String {
        type.contains("ssl") ? "https" : "http"
    }

    // MARK: - NetServiceBrowserDelegate

    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        logger.info("Found service: \(service.name, privacy: .public) type: \(service.type, privacy: .public)")

        let alreadyExists = state.withLockUnchecked { state in
            state.discoveredServices.contains { $0 === service }
        }

        if alreadyExists {
            return
        }

        state.withLockUnchecked { $0.discoveredServices.append(service) }
        service.delegate = self
        service.startMonitoring()
        service.resolve(withTimeout: 10)
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        logger.debug("Service removed: \(service.name, privacy: .public)")
        state.withLockUnchecked { state in
            state.discoveredServices.removeAll { $0.name == service.name && $0.type == service.type }
        }
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

        let key = ServiceAddressKey(name: service.name, type: service.type)

        var current = result
        while let info = current {
            if let sockaddr = info.pointee.ai_addr {
                var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let addrLen = socklen_t(info.pointee.ai_addrlen)

                if getnameinfo(sockaddr, addrLen, &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let rawAddress = stringFromCCharArray(hostBuffer)
                    let address = BonjourAddressUtils.stripZoneID(from: rawAddress)

                    if !BonjourAddressUtils.shouldFilterAddress(address) {
                        logger.debug("  DNS resolved: \(address, privacy: .public)")

                        state.withLockUnchecked { state in
                            if state.additionalAddresses[key] == nil {
                                state.additionalAddresses[key] = []
                            }
                            if !state.additionalAddresses[key]!.contains(address) {
                                state.additionalAddresses[key]!.append(address)
                            }
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

        let rawAddress = stringFromCCharArray(hostname)
        let address = BonjourAddressUtils.stripZoneID(from: rawAddress)

        // Filter unwanted addresses
        if BonjourAddressUtils.shouldFilterAddress(address) {
            return nil
        }

        // Format IPv6 with brackets
        return BonjourAddressUtils.formatForURL(address)
    }

    private func stringFromCCharArray(_ chars: [CChar]) -> String {
        chars.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return "" }
            return String(cString: baseAddress)
        }
    }
}

// MARK: - Test Helpers

#if DEBUG
extension BonjourService {
    /// Injects test state for unit testing cross-combination logic
    func injectTestState(addresses: Set<String>, schemePorts: [(scheme: String, port: Int)]) {
        state.withLockUnchecked { state in
            state.allDiscoveredAddresses = addresses
            state.allDiscoveredSchemePorts = Set(schemePorts.map { SchemePort(scheme: $0.scheme, port: $0.port) })
        }
    }
}
#endif
#endif
