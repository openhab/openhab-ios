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

//// Copyright (c) 2010-2025 Contributors to the openHAB project
////
//// See the NOTICE file(s) distributed with this work for additional
//// information.
////
//// This program and the accompanying materials are made available under the
//// terms of the Eclipse Public License 2.0 which is available at
//// http://www.eclipse.org/legal/epl-2.0
////
//// SPDX-License-Identifier: EPL-2.0
//
// import XCTest
// @testable import openHAB // Replace with actual module name
// import Intents
// import OpenHABCore
//
// final class SetSwitchStateIntentHandlerTests: XCTestCase {
//
//    final class MockItemCache: ItemCacheProtocol {
//        var lastCommand: String?
//
//        func getItem(name: String) async -> OpenHABItem? {
//            .mockSwitch(name: name)
//        }
//
//        func sendCommand(_ item: OpenHABItem, commandToSend: String) async {
//            lastCommand = commandToSend
//        }
//
//        func getItemNames(searchTerm: String?, types: [OpenHABItem.ItemType]?) -> [String] {
//            return ["MockSwitch"]
//        }
//    }
//
//    func testHandleIntentMissingItem() {
//        let intent = OpenHABSetSwitchStateIntent()
//        intent.item = nil
//        intent.action = "On"
//
//        let handler = SetSwitchStateIntentHandler(itemCache: MockItemCache())
//        let expectation = expectation(description: "Handle failure")
//
//        handler.handle(intent: intent) { response in
//            XCTAssertEqual(response.code, .failureInvalidItem)
//            expectation.fulfill()
//        }
//
//        wait(for: [expectation], timeout: 1)
//    }
// }
//
// extension OpenHABItem {
//    static func mockSwitch(name: String = "MockSwitch", state: String = "OFF") -> OpenHABItem {
//        return OpenHABItem(
//            name: name,
//            type: "Switch",
//            state: state,
//            link: "http://mock/api/items/\(name)",
//            label: name,
//            groupType: nil,
//            stateDescription: nil,
//            commandDescription: nil,
//            members: [],
//            category: nil,
//            options: nil
//        )
//    }
// }
