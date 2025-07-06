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

struct EndpointTests {
    @Test
    func returnsEmptyEndpointForNilOrEmptyIcon() {
        #expect(
            Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 3, icon: nil, state: "ON", iconType: .png, iconColor: "")
                == Endpoint(baseURL: "", path: "", queryItems: [])
        )

        #expect(
            Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 3, icon: "", state: "OFF", iconType: .svg, iconColor: "blue")
                == Endpoint(baseURL: "", path: "", queryItems: [])
        )
    }

    @Test
    func buildsClassicIconEndpoint() {
        let result = Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 3, icon: "light", state: "ON", iconType: .svg, iconColor: "")

        #expect(result.baseURL == "http://192.168.2.10:8080")
        #expect(result.path == "/icon/light")
        #expect(result.queryItems.contains(URLQueryItem(name: "format", value: "SVG")))
        #expect(result.queryItems.contains(URLQueryItem(name: "state", value: "ON")))
    }

    @Test
    func buildsMaterialIconWithIconify() {
        let result = Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 3, icon: "material:light_on", state: "", iconType: .svg, iconColor: "")

        #expect(result.baseURL == "https://api.iconify.design/")
        #expect(result.path == "/ic/baseline-light-on.svg")
        #expect(result.queryItems.contains(URLQueryItem(name: "height", value: "64")))
    }

    @Test
    func buildsF7IconWithIconify() {
        let result = Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 3, icon: "f7:alarm", state: "", iconType: .svg, iconColor: "")

        #expect(result.baseURL == "https://api.iconify.design/")
        #expect(result.path == "/f7/alarm.svg")
        #expect(result.queryItems.contains(URLQueryItem(name: "height", value: "64")))
    }

    @Test
    func addsColorQueryForIconify() {
        let result = Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 3, icon: "material:door_open", state: "", iconType: .png, iconColor: "#ff0000")

        #expect(result.baseURL == "https://api.iconify.design/")
        #expect(result.path.contains("door-open.svg"))
        #expect(result.queryItems.contains(URLQueryItem(name: "color", value: "#ff0000")))
    }

    @Test
    func returnsPNGIcon() {
        let result = Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 3, icon: "switch", state: "", iconType: .png, iconColor: "")

        #expect(result.queryItems.contains(URLQueryItem(name: "format", value: "PNG")))
    }

    @Test
    func handlesThreeSegmentIcon() {
        let result = Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 3, icon: "if:modern:fan", state: "", iconType: .svg, iconColor: "")

        #expect(result.baseURL == "https://api.iconify.design/")
        #expect(result.path == "/modern/fan.svg")
    }

    @Test
    func defaultsToNoneIconIfMalformed() {
        let result = Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 3, icon: "unknown:iconicIcon", state: "ON", iconType: .png, iconColor: "")

        #expect(result.baseURL == "http://192.168.2.10:8080")
        #expect(result.path == "/icon/none") // fallback to 2-part icon
    }

    @Test
    func version2() {
        let result = Endpoint.icon(rootUrl: "http://192.168.2.10:8080", version: 2, icon: "switch", state: "OFF", iconType: .svg, iconColor: "")
        #expect(result.baseURL == "http://192.168.2.10:8080")
        #expect(result.path == "/icon/switch")
        #expect(result.queryItems.contains(URLQueryItem(name: "format", value: "SVG")))
        #expect(result.queryItems.contains(URLQueryItem(name: "state", value: "OFF")))
    }
}
