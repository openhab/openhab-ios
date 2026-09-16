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

/// How a `NavigationCommand.switchToWebView(path:)` value should be handled.
enum WebViewRoute: Equatable {
    /// Load directly at this server-side path — Framework7 boots there on a cold
    /// launch, and `OpenHABRootView` routes to it client-side when already live.
    case path(String)
    /// No path was requested — just show the Main UI root.
    case root
    /// A raw client-side router command (not a "navigate:/page/…" shape) that only
    /// makes sense once the SPA reports SSE-connected.
    case liveCommand(String)
}

/// Decides how a `switchToWebView` navigation command should be routed, independent of
/// `OpenHABRootView`'s own state, so the decision tree can be unit tested directly.
enum WebViewNavigationRouter {
    /// - Parameter path: the `path` payload of a `NavigationCommand.switchToWebView(path:)`.
    static func route(for path: String?) -> WebViewRoute {
        guard let path else { return .root }
        if path.starts(with: "/") { return .path(path) }
        if let mainUIPath = mainUIPath(fromNavigateCommand: path) { return .path(mainUIPath) }
        return .liveCommand(path)
    }

    /// Extracts `/page/…` from a Framework7 router command of the form `"navigate:/page/…"`
    /// (the shape `NotificationCommandParser` produces for a `ui:navigate:/page/<pageId>`
    /// onClickAction). `nil` for anything else, including a bare "navigate:" with no path.
    static func mainUIPath(fromNavigateCommand command: String) -> String? {
        guard command.hasPrefix("navigate:") else { return nil }
        let path = command.dropFirst("navigate:".count)
        return path.hasPrefix("/") ? String(path) : nil
    }
}
