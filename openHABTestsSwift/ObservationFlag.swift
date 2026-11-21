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

/// Records that an `withObservationTracking` `onChange` handler fired.
final class ObservationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false

    var value: Bool {
        lock.withLock { fired }
    }

    func set() {
        lock.withLock { fired = true }
    }
}
