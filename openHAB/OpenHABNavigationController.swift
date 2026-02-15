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

// Copyright (c) 2010-2025 Contributors to the openHAB project
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
import UIKit

/// This is a wrapper around UINavigationController that allows the status bar to be hidden or shown.
/// It is used by the SwiftUI app shell when embedding legacy UIKit flows.
class OpenHABNavigationController: UINavigationController {
    override var childForStatusBarHidden: UIViewController? { nil }

    override var prefersStatusBarHidden: Bool {
        Preferences.shared.hideStatusBar
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { .fade }
}
