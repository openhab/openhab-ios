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

import SafariServices
import UIKit

/// Presents a URL in an in-app `SFSafariViewController` over the current key window.
///
/// `openSafari` got this isolation for free by living on `OpenHABRootView` (a SwiftUI
/// `View`, implicitly `@MainActor`); extracting it into its own type dropped that, so it
/// needs to be explicit here — `UIApplication.shared` and presenting a view controller
/// are both main-thread-only.
@MainActor
enum SafariPresenter {
    static func present(_ url: URL, entersReaderIfAvailable: Bool = false) {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = entersReaderIfAvailable
        let viewController = SFSafariViewController(url: url, configuration: config)
        UIApplication.shared.firstKeyWindow?.rootViewController?.present(viewController, animated: true)
    }
}
