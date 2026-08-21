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

import Observation
import OpenHABCore
import SwiftUI

@MainActor
@Observable
final class ToastService {
    static let shared = ToastService()

    var isPresented = false
    var title = ""
    var message = ""
    var actions: [NotificationActionItem] = []
    /// The notification's icon, resolved against the active connection so the banner can
    /// authenticate the request the same way NotificationRow does.
    var iconURL: URL?
    var connection: ConnectionInfo?
    var onTap: (() -> Void)?
    var onAction: ((NotificationActionItem) -> Void)?
    private(set) var showCount = 0

    private init() {}

    func show(
        title: String,
        message: String,
        actions: [NotificationActionItem] = [],
        iconURL: URL? = nil,
        connection: ConnectionInfo? = nil,
        onTap: (() -> Void)? = nil,
        onAction: ((NotificationActionItem) -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.actions = actions
        self.iconURL = iconURL
        self.connection = connection
        self.onTap = onTap
        self.onAction = onAction
        showCount &+= 1
        isPresented = true
    }
}
