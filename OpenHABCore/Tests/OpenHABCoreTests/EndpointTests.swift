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

import Foundation
@testable import OpenHABCore
import Testing

struct EndpointsTests {
    @Test
    func emptyIconReturnsEmptyEndpoint() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 3,
            icon: nil,
            state: "ON",
            iconType: .svg,
            iconColor: "#FF0000"
        )

        #expect(endpoint.baseURL.isEmpty)
        #expect(endpoint.path.isEmpty)
        #expect(endpoint.queryItems.isEmpty)
    }

    @Test
    func simpleIconName() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "switch",
            state: "OFF",
            iconType: .svg,
            iconColor: "#00FF00"
        )

        #expect(endpoint.baseURL == "https://example.org")
        #expect(endpoint.path == "/icon/switch")
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "state", value: "OFF")))
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "format", value: "SVG")))
    }

//    @Test
//    func iconWithTwoSegments_material() {
//        let endpoint = Endpoint.icon(
//            rootUrl: "https://example.org",
//            version: 4,
//            icon: "material:bolt",
//            state: "ON",
//            iconType: .png,
//            iconColor: "#123456"
//        )
//
//        #expect(endpoint.path == "/ic/baseline.svg")
//        #expect(endpoint.queryItems.contains(URLQueryItem(name: "color", value: "#123456")))
//    }

    @Test
    func iconWithThreeSegments_customSource() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "f7:solid:home",
            state: "ON",
            iconType: .svg,
            iconColor: "#ABCDEF"
        )

        #expect(endpoint.path == "/f7/home.svg")
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "color", value: "#ABCDEF")))
    }

    @Test
    func iconColorString() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "f7:solid:home",
            state: "ON",
            iconType: .svg,
            iconColor: "red"
        )

        #expect(endpoint.path == "/f7/home.svg")
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "color", value: "#FF0000")))
    }

    @Test
    func ohIcon1() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "light",
            state: "ON",
            iconType: .png,
            iconColor: "red"
        )

        #expect(endpoint.path == "/icon/light")
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "format", value: "PNG")))
    }

    @Test
    func ohIcon2() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "oh:light",
            state: "ON",
            iconType: .png,
            iconColor: "red"
        )

        #expect(endpoint.path == "/icon/light")
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "format", value: "PNG")))
    }

    @Test
    func ohIcon3() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "oh:classic:light",
            state: "ON",
            iconType: .png,
            iconColor: "red"
        )

        #expect(endpoint.path == "/icon/light")
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "format", value: "PNG")))
    }

    @Test
    func ohIcon4() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "oh:custom:light",
            state: "ON",
            iconType: .png,
            iconColor: "red"
        )

        #expect(endpoint.path == "/icon/light")
        #expect(endpoint.queryItems.contains(URLQueryItem(name: "format", value: "PNG")))
    }

    // TODO: test for iconset
//    "light" to "icon/light?format=PNG&anyFormat=true&iconset=classic",
//                "oh:light" to "icon/light?format=PNG&anyFormat=true&iconset=classic",
//                "oh:classic:light" to "icon/light?format=PNG&anyFormat=true&iconset=classic",
//                "oh:custom:light" to "icon/light?format=PNG&anyFormat=true&iconset=custom"

    // Test no state is transmitted
    // Test baseURL
    @Test
    func materialIcon1() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "material:light",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )

        // underscore should become "-"
        #expect(endpoint.path == "/ic/baseline-light.svg")
        // Test api.iconifyd.design
    }

    @Test
    func materialIcon2() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "material:outline:light",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )

        // underscore should become "-"
        #expect(endpoint.path == "/ic/outline-light.svg")
        // Test api.iconifyd.design
    }

    @Test
    func f7Icons1() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "f7:airplane",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )

        #expect(endpoint.path == "/f7/airplane.svg")
        // Test api.iconifyd.design
    }

    @Test
    func f7Icons2() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "f7:IGNORED:airplane",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )

        #expect(endpoint.path == "/f7/airplane.svg")
        // Test api.iconifyd.design
    }

    @Test
    func iconifyIcons1() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "if:codicon:lightbulb",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )

        #expect(endpoint.path == "/codicon/lightbulb.svg")
    }

    @Test
    func iconifyIcons2() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "iconify:codicon:lightbulb",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )

        #expect(endpoint.path == "/codicon/lightbulb.svg")
    }

    @Test
    func unknownIconSources1() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "unknown:ignored",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )

        #expect(endpoint.path == "/icon/none")
    }

    @Test
    func unknownIconSources2() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "unknown:ignored:ignored",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )

        #expect(endpoint.path == "/icon/none")
    }

    @Test
    func noneIcons1() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "none",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )

        #expect(endpoint.path == "/icon/none")
    }

    @Test
    func noneIcons2() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "oh:none",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )

        #expect(endpoint.path == "/icon/none")
    }

    @Test
    func noneIcons3() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "oh:classic:none",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )

        #expect(endpoint.path == "/icon/none")
    }

    @Test
    func noneIcons4() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "oh:foo:none",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )

        #expect(endpoint.path == "/icon/none")
    }

    @Test
    func noneIcons5() {
        let endpoint = Endpoint.icon(
            rootUrl: "https://example.org",
            version: 4,
            icon: "f7:none",
            state: "UP",
            iconType: .svg,
            iconColor: "#000000"
        )

        #expect(endpoint.path == "/f7/none.svg")
    }
}
