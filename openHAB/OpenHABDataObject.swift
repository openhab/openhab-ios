// Copyright (c) 2010-2023 Contributors to the openHAB project
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
import OpenHABCore
import UIKit

class OpenHABDataObject: NSObject, DataObject {
    var openHABRootUrl = ""
    var openHABUsername = ""
    var openHABPassword = ""
    var openHABAlwaysSendCreds = false
    var sitemapViewController: OpenHABSitemapViewController?
    var openHABVersion: Int = 0
    var currentWebViewPath = ""
    var currentView: TargetController?
}

extension OpenHABDataObject {
    convenience init(openHABRootUrl: String) {
        self.init()
        self.openHABRootUrl = openHABRootUrl
    }
}
