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

struct OpenHABJSONParserTests {
    let decoder: JSONDecoder

    init() {
        decoder = JSONDecoder.makeISO8601TolerantDecoder()
    }

    @Test func jSONNotificationDecoder() throws {
        // swiftlint:disable line_length
        let json = Data("""
                [{"_id":"5c82e14d2b48ecbf7a7223e0","message":"Light Küche was changed","__v":0,"created":"2019-03-08T21:40:29.412Z"},{"_id":"5c82c9c22b48ecbf7a70f44e","message":"Light Küche was changed","__v":0,"created":"2019-03-08T20:00:02.368Z"},{"_id":"5c82c9c02b48ecbf7a70f42c","message":"Light Küche was changed","__v":0,"created":"2019-03-08T20:00:00.982Z"},{"_id":"5c7fff782b48ecbf7a4dd8e4","message":"Light Küche was changed","__v":0,"created":"2019-03-06T17:12:24.093Z"},{"_id":"5c7ff5c12b48ecbf7a4d56fb","message":"Light Küche was changed","__v":0,"created":"2019-03-06T16:30:57.101Z"},{"_id":"5c7ed0852b48ecbf7a3d2151","message":"Light Küche was changed","__v":0,"created":"2019-03-05T19:39:49.373Z"},{"_id":"5c7d50ba2b48ecbf7a26948f","message":"Light Küche was changed","__v":0,"created":"2019-03-04T16:22:18.473Z"},{"_id":"5c7d50b62b48ecbf7a269455","message":"Light Küche was changed","__v":0,"created":"2019-03-04T16:22:14.321Z"},{"_id":"5c7d50b42b48ecbf7a269442","message":"Light Küche was changed","__v":0,"created":"2019-03-04T16:22:12.468Z"},{"_id":"5c7d507d2b48ecbf7a26916c","message":"Light Küche was changed","__v":0,"created":"2019-03-04T16:21:17.006Z"}]
        """.utf8)
        // swiftlint:enable line_length

        let codingData = try decoder.decode([OpenHABNotification.CodingData].self, from: json)
        #expect(codingData[0].message == "Light Küche was changed")
    }

    @Test func notificationDecodesOnClickAction() throws {
        let json = Data("""
        [{"_id":"abc123","message":"Door opened","__v":0,"created":"2024-01-01T00:00:00.000Z","on-click":"ui:/overview"}]
        """.utf8)

        let codingData = try decoder.decode([OpenHABNotification.CodingData].self, from: json)
        let notification = codingData[0].openHABNotification
        #expect(notification.onClickAction == "ui:/overview")
    }

    @Test func notificationDecodesActionsJSONString() throws {
        let actionsJSON = #"[{\"title\":\"Open\",\"action\":\"ui:/overview\"},{\"title\":\"Dismiss\",\"action\":\"\"}]"#
        let json = Data("""
        [{"_id":"abc456","message":"Motion detected","__v":0,"created":"2024-01-01T00:00:00.000Z","actions":"\(actionsJSON)"}]
        """.utf8)

        let codingData = try decoder.decode([OpenHABNotification.CodingData].self, from: json)
        let notification = codingData[0].openHABNotification
        #expect(notification.actions.count == 2)
        #expect(notification.actions[0].title == "Open")
        #expect(notification.actions[0].action == "ui:/overview")
        #expect(notification.actions[1].title == "Dismiss")
    }
}
