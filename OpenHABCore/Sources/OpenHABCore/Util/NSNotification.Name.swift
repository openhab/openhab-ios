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

public extension NSNotification.Name {
    /// Posted by AppDelegate when the app transitions to the active state.
    /// Subscribers outside the UIKit layer should use this instead of
    /// UIApplication.didBecomeActiveNotification.
    static let appDidBecomeActive = NSNotification.Name("org.openhab.appDidBecomeActive")
}
