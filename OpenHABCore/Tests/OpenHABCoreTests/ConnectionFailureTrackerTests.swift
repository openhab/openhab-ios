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

struct ConnectionFailureTrackerTests {
    @Test func shouldAttemptLogic() async {
        let tracker = ConnectionFailureTracker()
        await tracker.setEnabled(true)
        let config = ConnectionConfiguration(url: "http://test", username: "", password: "", priority: 1)

        var result = await tracker.shouldAttempt(config)
        #expect(result)

        await tracker.recordFailure(config)
        await tracker.recordFailure(config)
        await tracker.recordFailure(config)

        result = await tracker.shouldAttempt(config)
        #expect(!result)

        await tracker.reset(config)
        result = await tracker.shouldAttempt(config)
        #expect(result)
    }

    @Test func maxFailureCount() async {
        let tracker = ConnectionFailureTracker()
        await tracker.setEnabled(true)
        let config1 = ConnectionConfiguration(url: "http://a", username: "", password: "", priority: 0)
        let config2 = ConnectionConfiguration(url: "http://b", username: "", password: "", priority: 1)

        await tracker.recordFailure(config1)
        await tracker.recordFailure(config1)
        await tracker.recordFailure(config2)

        let max = await tracker.maxFailureCount()
        #expect(max == 2)
    }
}
