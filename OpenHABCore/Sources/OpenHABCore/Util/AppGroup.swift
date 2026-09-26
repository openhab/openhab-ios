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

/// The app group shared by the app, its extensions and the watch app.
public enum AppGroup {
    /// The official openHAB app group.
    public static let defaultIdentifier = "group.org.openhab.app"

    /// Read from the `OpenHABAppGroup` Info.plist key, which `Signing.xcconfig` derives
    /// from the bundle ID prefix, so contributors can build with their own team and group.
    /// Falls back to the official group where no Info.plist declares it, e.g. OpenHABCore's
    /// own test runner.
    public static let identifier = identifier(in: .main)

    static func identifier(in bundle: Bundle) -> String {
        bundle.object(forInfoDictionaryKey: "OpenHABAppGroup") as? String ?? defaultIdentifier
    }
}
