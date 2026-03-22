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

// Wrap real NWPathMonitor
final class RealPathMonitor: NWPathMonitoring, Sendable {
    private let monitor: NWPathMonitor

    init() {
        monitor = NWPathMonitor()
    }

    func startMonitoring(handler: @escaping (Bool) async -> Void) async {
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

// MARK: - AsyncStream wrapper for NWPathMonitor

// Avoids NWPathMonitor's native AsyncSequence conformance (iOS 17+), which has a
// bug where NWPathMonitor.startLocked(lockedState:) holds an internal os_unfair_lock
// and then calls AsyncStream.Continuation.finish() from within that locked context
// via makeAsyncStream(). finish() tries to re-acquire the same lock, causing
// _os_unfair_lock_recursive_abort on com.apple.network.connections.
//
// Our own paths() wrapper avoids makeAsyncStream() entirely. The onTermination
// handler defers cancel() off the AsyncStream._Storage lock context to prevent
// a symmetric re-entrancy risk on the other side.
extension NWPathMonitor {
    func paths() -> AsyncStream<NWPath> {
        AsyncStream { continuation in
            pathUpdateHandler = { path in
                continuation.yield(path)
            }
            continuation.onTermination = { [weak self] _ in
                DispatchQueue.global(qos: .utility).async { self?.cancel() }
            }
            start(queue: DispatchQueue(label: "NWPathMonitor.paths"))
        }
    }
}
