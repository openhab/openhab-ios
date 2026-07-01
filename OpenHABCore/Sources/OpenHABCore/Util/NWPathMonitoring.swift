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
import Network
import os.log

/// Wrap real NWPathMonitor
final class RealPathMonitor: NWPathMonitoring, Sendable {
    private let monitor: NWPathMonitor

    init() {
        monitor = NWPathMonitor()
    }

    func startMonitoring(handler: @escaping (Bool) async -> Void) async {
        // Use the manual paths() wrapper on all OS versions.
        // NWPathMonitor's native iOS 17 AsyncSequence conformance (makeAsyncStream()) has a
        // re-entrancy bug: startLocked() holds the monitor's os_unfair_lock and calls
        // AsyncStream.Continuation.finish(), whose onTermination callback tries to re-acquire
        // the same lock → os_unfair_lock_recursive_abort (crash seen on iOS 17.7.11).
        for await path in monitor.paths() {
            Logger.nwPathMonitoring.debug("Path monitor update: \(path.debugDescription)")
            await handler(path.status == .satisfied || path.status == .requiresConnection)
        }
    }

    func cancel() {
        monitor.cancel()
    }
}

// MARK: - Protocol

public protocol NWPathMonitoring: AnyObject, Sendable {
    /// Continuously monitors network connectivity status.
    /// Calls the handler with `true` when connected, `false` otherwise.
    func startMonitoring(handler: @escaping (Bool) async -> Void) async
    func cancel()
}

// MARK: - NWPathMonitor AsyncStream wrapper

extension NWPathMonitor {
    func paths() -> AsyncStream<NWPath> {
        AsyncStream { continuation in
            pathUpdateHandler = { path in
                continuation.yield(path)
            }
            continuation.onTermination = { [weak self] _ in
                self?.cancel()
            }
            start(queue: DispatchQueue(label: "NSPathMonitor.paths"))
        }
    }
}
