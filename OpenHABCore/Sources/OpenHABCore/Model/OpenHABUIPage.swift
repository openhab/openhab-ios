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

/// A UI page registered in the openHAB `ui:page` namespace.
/// Only pages with `sidebar: true` in their config are shown in the navigation menu.
public struct OpenHABUIPage: Sendable {
    public let uid: String
    public let label: String
    public let icon: String
    public let order: Int
    public let url: String

    public init(uid: String, label: String, icon: String, order: Int, url: String) {
        self.uid = uid
        self.label = label
        self.icon = icon
        self.order = order
        self.url = url
    }
}
