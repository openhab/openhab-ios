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
        var lastSignature: PathSignature?
        // Use the manual paths() wrapper on all OS versions.
        // NWPathMonitor's native iOS 17 AsyncSequence conformance (makeAsyncStream()) has a
        // re-entrancy bug: startLocked() holds the monitor's os_unfair_lock and calls
        // AsyncStream.Continuation.finish(), whose onTermination callback tries to re-acquire
        // the same lock → os_unfair_lock_recursive_abort (crash seen on iOS 17.7.11).
        for await path in monitor.paths() {
            let signature = PathSignature(path)
            // Ignore link-quality-only updates (LQM flaps): NWPathMonitor fires frequently as
            // signal strength changes, but those don't affect whether/how the server can be
            // reached. Only forward changes to connectivity or the set of available interfaces,
            // so a scheduled reconnection backoff isn't restarted by network noise.
            guard signature != lastSignature else {
                Logger.nwPathMonitoring.debug("Path update ignored (quality-only change): \(path.debugDescription)")
                continue
            }
            lastSignature = signature
            Logger.nwPathMonitoring.debug("Path monitor update: \(path.debugDescription)")
            await handler(signature.isConnected)
        }
    }

    func cancel() {
        monitor.cancel()
    }
}

/// The reachability-relevant fingerprint of an `NWPath`: its connectivity and the set of
/// available interface types. Deliberately excludes link quality, which flaps frequently
/// without changing whether or how the network can be reached.
private struct PathSignature: Equatable {
    let isConnected: Bool
    let interfaces: Set<NWInterface.InterfaceType>

    init(_ path: NWPath) {
        isConnected = path.status == .satisfied || path.status == .requiresConnection
        interfaces = Set(path.availableInterfaces.map(\.type))
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
