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

// Standalone Bonjour Discovery Tool
// Build: cd BonjourDiscoveryTool && swift build
// Run: .build/debug/bonjour-discovery

import Foundation

// MARK: - String Extension

extension String {
    func repeated(_ times: Int) -> String {
        String(repeating: self, count: times)
    }
}

// MARK: - Local Interfaces

func printLocalInterfaces() {
    print("Local Network Interfaces:")
    print("-".repeated(40))

    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
        print("   Could not get interfaces")
        return
    }
    defer { freeifaddrs(ifaddr) }

    var current: UnsafeMutablePointer<ifaddrs>? = firstAddr
    while let interface = current {
        let family = interface.pointee.ifa_addr.pointee.sa_family

        if family == UInt8(AF_INET) || family == UInt8(AF_INET6) {
            let name = String(cString: interface.pointee.ifa_name)

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let addr = interface.pointee.ifa_addr
            let addrLen = family == UInt8(AF_INET)
                ? socklen_t(MemoryLayout<sockaddr_in>.size)
                : socklen_t(MemoryLayout<sockaddr_in6>.size)

            if getnameinfo(addr, addrLen, &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                var address = String(cString: hostname)

                // Skip link-local and loopback
                if !address.hasPrefix("fe80:"), !address.hasPrefix("127."), address != "::1" {
                    // Remove scope ID for IPv6
                    if let percentIndex = address.firstIndex(of: "%") {
                        address = String(address[..<percentIndex])
                    }
                    print("   \(name): \(address)")
                }
            }
        }
        current = interface.pointee.ifa_next
    }
}

func printSummary(_ servers: [DiscoveredServer]) {
    print()
    print("=".repeated(60))
    print("Discovery Summary")
    print("=".repeated(60))
    print()

    if servers.isEmpty {
        print("No servers found")
    } else {
        let uniqueAddresses = Set(servers.map(\.address))
        let uniquePorts = Set(servers.map { "\($0.scheme):\($0.port)" })

        print("Cross-combined \(uniqueAddresses.count) address(es) x \(uniquePorts.count) endpoint(s) = \(servers.count) URL(s):")
        for server in servers.sorted(by: { $0.url < $1.url }) {
            print("   \(server.url)")
        }
        print()
        print("Unique addresses: \(uniqueAddresses.sorted().joined(separator: ", "))")
        print("Unique endpoints: \(uniquePorts.sorted().joined(separator: ", "))")
    }

    print()
    printLocalInterfaces()
    print()
}

// MARK: - Main

func printUsage() {
    print("Usage: bonjour-discovery [options]")
    print("Options:")
    print("  -c, --cycles N     Number of discovery cycles (default: 1)")
    print("  -d, --duration N   Duration per cycle in seconds (default: 10)")
    print("  -h, --help         Show this help")
    print()
}

var cycles = 1
var duration: TimeInterval = 10

var args = CommandLine.arguments.dropFirst()
while let arg = args.first {
    args = args.dropFirst()
    switch arg {
    case "-c", "--cycles":
        if let value = args.first, let n = Int(value) {
            cycles = n
            args = args.dropFirst()
        }
    case "-d", "--duration":
        if let value = args.first, let n = Int(value) {
            duration = TimeInterval(n)
            args = args.dropFirst()
        }
    case "-h", "--help":
        printUsage()
        exit(0)
    default:
        break
    }
}

print()
print("=".repeated(60))
print("  openHAB Bonjour Discovery Tool")
print("=".repeated(60))
print()

let service = BonjourService()
var discoveredServers: [DiscoveredServer] = []

print("Starting Bonjour discovery...")
print("   Cycles: \(cycles), Duration per cycle: \(Int(duration))s")
print()

service.start(
    cycles: cycles,
    cycleDuration: duration,
    onUpdate: { servers in
        discoveredServers = servers
        print("   Found \(servers.count) server(s) so far...")
    },
    onComplete: {
        printSummary(discoveredServers)
        exit(0)
    }
)

// Run the main dispatch loop to allow callbacks to execute
dispatchMain()
