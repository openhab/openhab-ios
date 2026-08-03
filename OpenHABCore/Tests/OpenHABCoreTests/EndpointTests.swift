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
@testable import OpenHABCore
import Testing

struct EndpointTests {
    @Test
    func returnsNilEndpointForNilOrEmptyIcon() {
        #expect(
            Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 3, icon: nil, state: "ON", iconType: .png, iconColor: "")
                == nil
        )

        #expect(
            Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 3, icon: "", state: "OFF", iconType: .svg, iconColor: "blue")
                == nil
        )
    }

    @Test
    func buildsClassicIconEndpoint() throws {
        let result = Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 3, icon: "light", state: "ON", iconType: .svg, iconColor: "")
        let endpoint = try #require(result)

        #expect(endpoint.baseURL == "http://192.168.2.10:8080")
        #expect(endpoint.path == "/icon/light")
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "format", value: "SVG")))
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "state", value: "ON")))
    }

    @Test
    func buildsMaterialIconWithIconify() throws {
        let result = Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 3, icon: "material:light_on", state: "", iconType: .svg, iconColor: "")
        let endpoint = try #require(result)

        #expect(endpoint.baseURL == "https://api.iconify.design/")
        #expect(endpoint.path == "/ic/baseline-light-on.svg")
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "height", value: "64")))
    }

    @Test
    func buildsF7IconWithIconify() throws {
        let result = Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 3, icon: "f7:alarm", state: "", iconType: .svg, iconColor: "")
        let endpoint = try #require(result)

        #expect(endpoint.baseURL == "https://api.iconify.design/")
        #expect(endpoint.path == "/f7/alarm.svg")
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "height", value: "64")))
    }

    @Test
    func addsColorQueryForIconify() throws {
        let result = Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 3, icon: "material:door_open", state: "", iconType: .png, iconColor: "#ff0000")
        let endpoint = try #require(result)

        #expect(endpoint.baseURL == "https://api.iconify.design/")
        #expect(endpoint.path.contains("door-open.svg"))
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "color", value: "#FF0000")))
    }

    @Test
    func returnsPNGIcon() throws {
        let result = Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 3, icon: "switch", state: "", iconType: .png, iconColor: "")
        let endpoint = try #require(result)

        #expect(endpoint.queryItems.contains(URLQueryItem(name: "format", value: "PNG")))
    }

    @Test
    func handlesThreeSegmentIcon() throws {
        let result = Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 3, icon: "if:modern:fan", state: "", iconType: .svg, iconColor: "")
        let endpoint = try #require(result)

        #expect(endpoint.baseURL == "https://api.iconify.design/")
        #expect(endpoint.path == "/modern/fan.svg")
    }

    @Test
    func defaultsToNoneIconIfMalformed() throws {
        let result = Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 3, icon: "unknown:iconicIcon", state: "ON", iconType: .png, iconColor: "")
        let endpoint = try #require(result)

        #expect(endpoint.baseURL == "http://192.168.2.10:8080")
        #expect(endpoint.path == "/icon/none") // fallback to 2-part icon
    }

    @Test
    func version2() throws {
        let result = Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 2, icon: "switch", state: "OFF", iconType: .svg, iconColor: "")
        let endpoint = try #require(result)

        #expect(endpoint.baseURL == "http://192.168.2.10:8080")
        #expect(endpoint.path == "/icon/switch")
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "format", value: "SVG")))
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "state", value: "OFF")))
    }

    @Test
    func emptyIconReturnsNilEndpoint() {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 3,
            icon: nil,
            state: "ON",
            iconType: .svg,
            iconColor: "#FF0000"
        )
        #expect(result == nil)
    }

    @Test
    func simpleIconName() throws {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "switch",
            state: "OFF",
            iconType: .svg,
            iconColor: "#00FF00"
        )
        let endpoint = try #require(result)

        #expect(endpoint.baseURL == "https://example.org")
        #expect(endpoint.path == "/icon/switch")
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "state", value: "OFF")))
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "format", value: "SVG")))
    }

    @Test
    func iconWithThreeSegments_customSource() throws {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "f7:solid:home",
            state: "ON",
            iconType: .svg,
            iconColor: "#ABCDEF"
        )
        let endpoint = try #require(result)

        #expect(endpoint.path == "/f7/home.svg")
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "color", value: "#ABCDEF")))
    }

    @Test
    func iconColorString() throws {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "f7:solid:home",
            state: "ON",
            iconType: .svg,
            iconColor: "red"
        )
        let endpoint = try #require(result)

        #expect(endpoint.path == "/f7/home.svg")
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "color", value: "#FF0000")))
    }

    @Test
    func ohIcon1() throws {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "light",
            state: "ON",
            iconType: .png,
            iconColor: "red"
        )
        let endpoint = try #require(result)

        #expect(endpoint.path == "/icon/light")
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "format", value: "PNG")))
    }

    @Test
    func ohIcon2() throws {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "oh:light",
            state: "ON",
            iconType: .png,
            iconColor: "red"
        )
        let endpoint = try #require(result)

        #expect(endpoint.path == "/icon/light")
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "format", value: "PNG")))
    }

    @Test
    func ohIcon3() throws {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "oh:classic:light",
            state: "ON",
            iconType: .png,
            iconColor: "red"
        )
        let endpoint = try #require(result)

        #expect(endpoint.path == "/icon/light")
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "format", value: "PNG")))
    }

    @Test
    func ohIcon4() throws {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "oh:custom:light",
            state: "ON",
            iconType: .png,
            iconColor: "red"
        )
        let endpoint = try #require(result)

        #expect(endpoint.path == "/icon/light")
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "format", value: "PNG")))
    }

    @Test
    func classicNumberIconReturnsNil() {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "number",
            state: "80.0",
            iconType: .svg,
            iconColor: "#000000"
        )
        #expect(result == nil)
    }

    // TODO: test for iconset
//    "light" to "icon/light?format=PNG&anyFormat=true&iconset=classic",
//                "oh:light" to "icon/light?format=PNG&anyFormat=true&iconset=classic",
//                "oh:classic:light" to "icon/light?format=PNG&anyFormat=true&iconset=classic",
//                "oh:custom:light" to "icon/light?format=PNG&anyFormat=true&iconset=custom"

    /// Test no state is transmitted
    /// Test baseURL
    @Test
    func materialIcon1() throws {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "material:light",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )
        let endpoint = try #require(result)

        // underscore should become "-"
        #expect(endpoint.path == "/ic/baseline-light.svg")
        // Test api.iconifyd.design
    }

    @Test
    func materialIcon2() throws {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "material:outline:light",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )
        let endpoint = try #require(result)

        // underscore should become "-"
        #expect(endpoint.path == "/ic/outline-light.svg")
        // Test api.iconifyd.design
    }

    @Test
    func f7Icons1() throws {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "f7:airplane",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )
        let endpoint = try #require(result)

        #expect(endpoint.path == "/f7/airplane.svg")
        // Test api.iconifyd.design
    }

    @Test
    func f7Icons2() throws {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "f7:IGNORED:airplane",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )
        let endpoint = try #require(result)

        #expect(endpoint.path == "/f7/airplane.svg")
        // Test api.iconifyd.design
    }

    @Test
    func iconifyIcons1() throws {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "if:codicon:lightbulb",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )
        let endpoint = try #require(result)

        #expect(endpoint.path == "/codicon/lightbulb.svg")
    }

    @Test
    func iconifyIcons2() throws {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "iconify:codicon:lightbulb",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )
        let endpoint = try #require(result)

        #expect(endpoint.path == "/codicon/lightbulb.svg")
    }

    @Test
    func unknownIconSources1() throws {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "unknown:ignored",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )
        let endpoint = try #require(result)

        #expect(endpoint.path == "/icon/none")
    }

    @Test
    func unknownIconSources2() throws {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "unknown:ignored:ignored",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )
        let endpoint = try #require(result)

        #expect(endpoint.path == "/icon/none")
    }

    @Test
    func noneIcons1() throws {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "none",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )
        let endpoint = try #require(result)

        #expect(endpoint.path == "/icon/none")
    }

    @Test
    func noneIcons2() throws {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "oh:none",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )
        let endpoint = try #require(result)

        #expect(endpoint.path == "/icon/none")
    }

    @Test
    func noneIcons3() throws {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "oh:classic:none",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )
        let endpoint = try #require(result)

        #expect(endpoint.path == "/icon/none")
    }

    @Test
    func noneIcons4() throws {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "oh:foo:none",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )
        let endpoint = try #require(result)

        #expect(endpoint.path == "/icon/none")
    }

    @Test
    func noneIcons5() throws {
        let result = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "f7:none",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )
        let endpoint = try #require(result)

        #expect(endpoint.path == "/f7/none.svg")
    }
}
