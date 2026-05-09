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

@testable import OpenHABCore
import Testing

// MARK: - DiscoveredServer Tests

@Suite("DiscoveredServer")
struct DiscoveredServerTests {
    @Test
    func urlFormatsCorrectlyForIPv4() {
        let server = DiscoveredServer(scheme: "http", address: "192.168.1.100", port: 8080)
        #expect(server.url == "http://192.168.1.100:8080")
    }

    @Test
    func urlFormatsCorrectlyForIPv6WithBrackets() {
        let server = DiscoveredServer(scheme: "https", address: "[2001:db8::1]", port: 443)
        #expect(server.url == "https://[2001:db8::1]:443")
    }

    @Test
    func urlFormatsCorrectlyForHttps() {
        let server = DiscoveredServer(scheme: "https", address: "192.168.1.1", port: 8443)
        #expect(server.url == "https://192.168.1.1:8443")
    }

    @Test
    func hashableConformance() {
        let server1 = DiscoveredServer(scheme: "http", address: "192.168.1.1", port: 8080)
        let server2 = DiscoveredServer(scheme: "http", address: "192.168.1.1", port: 8080)
        let server3 = DiscoveredServer(scheme: "https", address: "192.168.1.1", port: 8443)

        #expect(server1 == server2)
        #expect(server1 != server3)

        let set: Set<DiscoveredServer> = [server1, server2, server3]
        #expect(set.count == 2)
    }

    @Test
    func sendableConformance() async {
        let server = DiscoveredServer(scheme: "http", address: "localhost", port: 8080)

        let result = await Task.detached {
            server.url
        }.value

        #expect(result == "http://localhost:8080")
    }
}

// MARK: - Address Filtering Tests

@Suite("BonjourAddressUtils.shouldFilterAddress")
struct AddressFilteringTests {
    // MARK: - Link-Local IPv6 (fe80:)

    @Test
    func filtersLinkLocalIPv6() {
        #expect(BonjourAddressUtils.shouldFilterAddress("fe80::1") == true)
        #expect(BonjourAddressUtils.shouldFilterAddress("fe80::a1:b2:c3:d4") == true)
        #expect(BonjourAddressUtils.shouldFilterAddress("fe80:0000:0000:0000:0000:0000:0000:0001") == true)
    }

    // MARK: - Loopback IPv4 (127.*)

    @Test
    func filtersLoopbackIPv4() {
        #expect(BonjourAddressUtils.shouldFilterAddress("127.0.0.1") == true)
        #expect(BonjourAddressUtils.shouldFilterAddress("127.0.1.1") == true)
        #expect(BonjourAddressUtils.shouldFilterAddress("127.255.255.255") == true)
    }

    // MARK: - Loopback IPv6 (::1)

    @Test
    func filtersLoopbackIPv6() {
        #expect(BonjourAddressUtils.shouldFilterAddress("::1") == true)
    }

    // MARK: - Unique Local IPv6 (fc*, fd*)

    @Test
    func filtersUniqueLocalIPv6_fc() {
        #expect(BonjourAddressUtils.shouldFilterAddress("fc00::1") == true)
        #expect(BonjourAddressUtils.shouldFilterAddress("fcab:1234::5678") == true)
    }

    @Test
    func filtersUniqueLocalIPv6_fd() {
        #expect(BonjourAddressUtils.shouldFilterAddress("fd00::1") == true)
        #expect(BonjourAddressUtils.shouldFilterAddress("fd12:3456:789a::1") == true)
    }

    // MARK: - Valid Addresses (Should NOT Be Filtered)

    @Test
    func allowsPrivateIPv4() {
        #expect(BonjourAddressUtils.shouldFilterAddress("192.168.1.1") == false)
        #expect(BonjourAddressUtils.shouldFilterAddress("10.0.0.1") == false)
        #expect(BonjourAddressUtils.shouldFilterAddress("172.16.0.1") == false)
    }

    @Test
    func allowsPublicIPv4() {
        #expect(BonjourAddressUtils.shouldFilterAddress("8.8.8.8") == false)
        #expect(BonjourAddressUtils.shouldFilterAddress("1.1.1.1") == false)
    }

    @Test
    func allowsGlobalIPv6() {
        #expect(BonjourAddressUtils.shouldFilterAddress("2001:db8::1") == false)
        #expect(BonjourAddressUtils.shouldFilterAddress("2607:f8b0:4004:800::200e") == false)
    }

    // MARK: - Edge Cases

    @Test
    func doesNotFilterAddressesStartingWithFe_notFe80() {
        // "fe00::" is not link-local, only "fe80::" is
        #expect(BonjourAddressUtils.shouldFilterAddress("fe00::1") == false)
        #expect(BonjourAddressUtils.shouldFilterAddress("fea0::1") == false)
    }

    @Test
    func doesNotFilterAddressesStartingWith127_nonIPv4Format() {
        // Edge case: something starting with 127 but not IPv4 loopback
        #expect(BonjourAddressUtils.shouldFilterAddress("1270::1") == false)
    }
}

// MARK: - Zone ID Stripping Tests

@Suite("BonjourAddressUtils.stripZoneID")
struct ZoneIDStrippingTests {
    @Test
    func stripsZoneIDFromIPv6() {
        #expect(BonjourAddressUtils.stripZoneID(from: "fe80::1%en0") == "fe80::1")
        #expect(BonjourAddressUtils.stripZoneID(from: "fe80::1%utun0") == "fe80::1")
        #expect(BonjourAddressUtils.stripZoneID(from: "2001:db8::1%eth0") == "2001:db8::1")
    }

    @Test
    func preservesAddressWithoutZoneID() {
        #expect(BonjourAddressUtils.stripZoneID(from: "192.168.1.1") == "192.168.1.1")
        #expect(BonjourAddressUtils.stripZoneID(from: "2001:db8::1") == "2001:db8::1")
        #expect(BonjourAddressUtils.stripZoneID(from: "::1") == "::1")
    }

    @Test
    func handlesEmptyString() {
        #expect(BonjourAddressUtils.stripZoneID(from: "").isEmpty)
    }
}

// MARK: - IPv6 URL Formatting Tests

@Suite("BonjourAddressUtils.formatForURL")
struct IPv6FormattingTests {
    @Test
    func addsBracketsToIPv6() {
        #expect(BonjourAddressUtils.formatForURL("2001:db8::1") == "[2001:db8::1]")
        #expect(BonjourAddressUtils.formatForURL("::1") == "[::1]")
        #expect(BonjourAddressUtils.formatForURL("fe80::1") == "[fe80::1]")
    }

    @Test
    func preservesExistingBrackets() {
        #expect(BonjourAddressUtils.formatForURL("[2001:db8::1]") == "[2001:db8::1]")
        #expect(BonjourAddressUtils.formatForURL("[::1]") == "[::1]")
    }

    @Test
    func preservesIPv4Addresses() {
        #expect(BonjourAddressUtils.formatForURL("192.168.1.1") == "192.168.1.1")
        #expect(BonjourAddressUtils.formatForURL("10.0.0.1") == "10.0.0.1")
        #expect(BonjourAddressUtils.formatForURL("127.0.0.1") == "127.0.0.1")
    }

    @Test
    func handlesEmptyString() {
        #expect(BonjourAddressUtils.formatForURL("").isEmpty)
    }
}

// MARK: - Cross-Combination Tests

#if !os(watchOS)
@Suite("BonjourService.getDiscoveredServers")
struct GetDiscoveredServersTests {
    @Test
    func returnsEmptyWhenNoDiscovery() {
        let service = BonjourService()
        let servers = service.getDiscoveredServers()
        #expect(servers.isEmpty)
    }

    @Test
    func crossCombinesAddressesAndSchemePorts() {
        let service = BonjourService()
        service.injectTestState(
            addresses: ["192.168.1.1", "[2001:db8::1]"],
            schemePorts: [
                (scheme: "http", port: 8080),
                (scheme: "https", port: 8443)
            ]
        )

        let servers = service.getDiscoveredServers()

        #expect(servers.count == 4) // 2 addresses x 2 schemePorts

        // Verify all combinations exist
        #expect(servers.contains { $0.url == "http://192.168.1.1:8080" })
        #expect(servers.contains { $0.url == "https://192.168.1.1:8443" })
        #expect(servers.contains { $0.url == "http://[2001:db8::1]:8080" })
        #expect(servers.contains { $0.url == "https://[2001:db8::1]:8443" })
    }

    @Test
    func returnsSortedByAddressThenScheme() {
        let service = BonjourService()
        service.injectTestState(
            addresses: ["192.168.1.2", "192.168.1.1", "10.0.0.1"],
            schemePorts: [
                (scheme: "https", port: 443),
                (scheme: "http", port: 80)
            ]
        )

        let servers = service.getDiscoveredServers()

        // Addresses should be sorted alphabetically
        #expect(servers[0].address == "10.0.0.1")
        #expect(servers[2].address == "192.168.1.1")
        #expect(servers[4].address == "192.168.1.2")

        // Schemes should be sorted within each address group (http before https)
        #expect(servers[0].scheme == "http")
        #expect(servers[1].scheme == "https")
    }

    @Test
    func handlesEmptyAddresses() {
        let service = BonjourService()
        service.injectTestState(
            addresses: [],
            schemePorts: [(scheme: "http", port: 8080)]
        )

        let servers = service.getDiscoveredServers()
        #expect(servers.isEmpty)
    }

    @Test
    func handlesEmptySchemePorts() {
        let service = BonjourService()
        service.injectTestState(
            addresses: ["192.168.1.1"],
            schemePorts: []
        )

        let servers = service.getDiscoveredServers()
        #expect(servers.isEmpty)
    }

    @Test
    func handlesSingleAddressSingleSchemePort() {
        let service = BonjourService()
        service.injectTestState(
            addresses: ["192.168.1.1"],
            schemePorts: [(scheme: "http", port: 8080)]
        )

        let servers = service.getDiscoveredServers()

        #expect(servers.count == 1)
        #expect(servers[0].url == "http://192.168.1.1:8080")
    }
}
#endif

// MARK: - BonjourServiceType Tests

@Suite("BonjourServiceType")
struct BonjourServiceTypeTests {
    @Test
    func httpsTypeReturnsHttpsScheme() {
        #expect(BonjourServiceType.https.scheme == "https")
    }

    @Test
    func httpTypeReturnsHttpScheme() {
        #expect(BonjourServiceType.http.scheme == "http")
    }

    @Test
    func httpsTypeHasCorrectRawValue() {
        #expect(BonjourServiceType.https.rawValue == "_openhab-server-ssl._tcp.")
    }

    @Test
    func httpTypeHasCorrectRawValue() {
        #expect(BonjourServiceType.http.rawValue == "_openhab-server._tcp.")
    }

    @Test
    func allCasesContainsBothTypes() {
        #expect(BonjourServiceType.allCases.count == 2)
        #expect(BonjourServiceType.allCases.contains(.http))
        #expect(BonjourServiceType.allCases.contains(.https))
    }
}
