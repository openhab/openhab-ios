// Copyright (c) 2010-2020 Contributors to the openHAB project
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

enum OpenHABDrawerItem {
    case settings
    case notifications
    case habpanel

    var localizedString: String {
        switch self {
        case .settings:
            return NSLocalizedString("settings", comment: "")
        case .notifications:
            return NSLocalizedString("notifications", comment: "")
        case .habpanel:
            return NSLocalizedString("habpanel", comment: "")
        }
    }

    static func openHABDrawerItem(localizedString: String) -> OpenHABDrawerItem {
        switch localizedString {
        case OpenHABDrawerItem.settings.localizedString:
            return OpenHABDrawerItem.settings
        case OpenHABDrawerItem.notifications.localizedString:
            return OpenHABDrawerItem.notifications
        default:
            return OpenHABDrawerItem.settings
        }
    }
}
