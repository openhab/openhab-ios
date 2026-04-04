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
import OpenAPIRuntime

/// A UI page registered in the openHAB `ui:page` namespace.
/// Only pages with `navbarOrder` set are shown in the navigation menu.
public struct OpenHABUIPage: Sendable {
    public let uid: String
    public let label: String
    public let icon: String
    public let navbarOrder: Int
    public let url: String

    public init(uid: String, label: String, icon: String, navbarOrder: Int, url: String) {
        self.uid = uid
        self.label = label
        self.icon = icon
        self.navbarOrder = navbarOrder
        self.url = url
    }
}

extension OpenHABUIPage {
    /// Build a page from a RootUIComponent, using `rootUrl` to construct the in-app URL.
    /// Returns `nil` if the component lacks a `uid`, lacks `navbarOrder` in config,
    /// or if the URL cannot be formed.
    init?(_ component: Components.Schemas.RootUIComponent, rootUrl: String) {
        guard let uid = component.uid, !uid.isEmpty,
              let config = component.config?.additionalProperties,
              let orderValue = config["navbarOrder"]?.value
        else { return nil }

        // navbarOrder arrives from JSON as Int or Double depending on parser
        let order: Int
        if let intOrder = orderValue as? Int {
            order = intOrder
        } else if let doubleOrder = orderValue as? Double {
            order = Int(doubleOrder)
        } else {
            return nil
        }

        let label = config["label"]?.value as? String ?? uid
        let icon = config["icon"]?.value as? String ?? ""
        let url = "\(rootUrl.removeTrailingSlashes())/ui/#/\(uid)"

        self.init(uid: uid, label: label, icon: icon, navbarOrder: order, url: url)
    }
}
