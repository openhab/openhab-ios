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
import Network

// Wrap real NWPathMonitor
final class RealPathMonitor: NWPathMonitoring {
    private let monitor: NWPathMonitor
    private var task: Task<Void, Never>?

    init() {
        monitor = NWPathMonitor()
    }

    func setUpdateHandler(_ handler: @escaping (Bool) -> Void) {
        if #available(iOS 17, watchOS 10, *) {
            task = Task {
                for await path in monitor {
                    handler(path.status == .satisfied)
                }
            }
        } else {
            monitor.pathUpdateHandler = { path in
                handler(path.status == .satisfied)
            }
        }
    }

    func start(queue: DispatchQueue) {
        monitor.start(queue: queue)
    }

    func cancel() {
        monitor.cancel()
        task?.cancel()
    }
}

// MARK: - Protocol

public protocol NWPathMonitoring: AnyObject {
    /// Called with `true` when connected, `false` otherwise.
    func setUpdateHandler(_ handler: @escaping (Bool) -> Void)
    func start(queue: DispatchQueue)
    func cancel()
}
