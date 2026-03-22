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
        if #available(iOS 17, watchOS 10, *) {
            for await path in monitor {
                Logger.nwPathMonitoring.debug("Path monitor update: \(path.debugDescription)")
                await handler(path.status == .satisfied || path.status == .requiresConnection)
            }
        } else {
            for await path in monitor.paths() {
                await handler(path.status == .satisfied || path.status == .requiresConnection)
            }
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

// MARK: Extension for version iOS <17

// this line breaks availability checking, since watchos 10 is minimum for the app
// @available(watchOS, obsoleted: 10.0)
@available(iOS, obsoleted: 17.0)
extension NWPathMonitor {
    func paths() -> AsyncStream<NWPath> {
        AsyncStream { continuation in
            pathUpdateHandler = { path in
                continuation.yield(path)
            }
            continuation.onTermination = { [weak self] _ in
                DispatchQueue.global(qos: .utility).async { self?.cancel() }
            }
            start(queue: DispatchQueue(label: "NSPathMonitor.paths"))
        }
    }
}
