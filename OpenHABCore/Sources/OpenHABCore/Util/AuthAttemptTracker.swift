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

public actor AuthAttemptTracker {
    private var attemptCounts: [URLSessionTask: Int] = [:]

    func incrementAttempt(for task: URLSessionTask) -> Int {
        attemptCounts[task, default: 0] += 1
        return attemptCounts[task]!
    }

    func resetAttempt(for task: URLSessionTask?) {
        guard let task else { return }
        attemptCounts[task] = 0
    }
}
