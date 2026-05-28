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
/// It is used to control the status bar for the entire app and is loaded from the Main storyboard entry point.
class OpenHABNavigationController: UINavigationController {
    override var childForStatusBarHidden: UIViewController? {
        nil
    }

    override var prefersStatusBarHidden: Bool {
        Preferences.shared.hideStatusBar
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        .fade
    }
}
