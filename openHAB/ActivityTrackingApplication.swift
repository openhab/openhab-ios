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

import UIKit

/// Resets the screensaver idle timer on every touch. Wired in via the
/// `NSPrincipalClass` key in Info.plist.
final class ActivityTrackingApplication: UIApplication {
    override func sendEvent(_ event: UIEvent) {
        super.sendEvent(event)

        guard event.type == .touches,
              let touches = event.allTouches,
              touches.contains(where: { $0.phase == .began || $0.phase == .moved || $0.phase == .ended })
        else { return }

        ScreenSaverManager.shared.noteUserActivity()
    }
}
