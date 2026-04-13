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

import OpenHABCore
import SwiftUI

struct SitemapRowActions: Sendable {
    var sendCommand: @MainActor @Sendable (_ itemName: String, _ command: String, _ policy: WidgetCommandPolicy, _ phase: WidgetCommandPhase) -> Void
    var cancelPendingCommand: @MainActor @Sendable (_ itemName: String, _ key: String?) -> Void
    var sendNumericUpdate: @MainActor @Sendable (_ itemName: String, _ value: Double, _ unit: String?, _ format: String?, _ policy: WidgetCommandPolicy, _ phase: WidgetCommandPhase, _ key: String?) -> Void

    static let noop = SitemapRowActions(
        sendCommand: { _, _, _, _ in },
        cancelPendingCommand: { _, _ in },
        sendNumericUpdate: { _, _, _, _, _, _, _ in }
    )
}

private struct SitemapRowActionsKey: EnvironmentKey {
    static let defaultValue = SitemapRowActions.noop
}

extension EnvironmentValues {
    var sitemapRowActions: SitemapRowActions {
        get { self[SitemapRowActionsKey.self] }
        set { self[SitemapRowActionsKey.self] = newValue }
    }
}
