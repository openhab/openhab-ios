// Copyright (c) 2010-2019 Contributors to the openHAB project
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

// Inspired by http://danielemargutti.com/2017/10/19/throttle-in-swift/

public class Throttler {
    private let queue: DispatchQueue = .global(qos: .background)

    private var job = DispatchWorkItem {}
    private var previousRun: Date = .distantPast
    private var maxInterval: TimeInterval

    init(maxInterval: TimeInterval) {
        self.maxInterval = maxInterval
    }

    func throttle(block: @escaping () -> Void) {
        job.cancel()
        job = DispatchWorkItem { [weak self] in
            self?.previousRun = Date()
            block()
        }
        let delay = Date().timeIntervalSince(previousRun) > maxInterval ? 0 : maxInterval
        queue.asyncAfter(deadline: .now() + Double(delay), execute: job)
    }
}
