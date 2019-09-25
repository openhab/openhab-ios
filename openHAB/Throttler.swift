//
//  Throttler.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 23.09.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

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
