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

import UIKit

/// Centralises UIApplication.isIdleTimerDisabled so callers outside the
/// UIKit layer do not need to import UIKit directly.
@MainActor
final class IdleTimerService {
    static let shared = IdleTimerService()
    private init() {}

    var isDisabled: Bool {
        get { UIApplication.shared.isIdleTimerDisabled }
        set { UIApplication.shared.isIdleTimerDisabled = newValue }
    }
}
