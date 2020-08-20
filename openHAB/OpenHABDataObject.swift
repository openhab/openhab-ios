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
import OpenHABCore

class OpenHABDataObject: NSObject, DataObject {
    var openHABRootUrl = ""
    var openHABUsername = ""
    var openHABPassword = ""
    var openHABAlwaysSendCreds = false
    var rootViewController: OpenHABViewController?
    var openHABVersion: Int = 0
}

extension OpenHABDataObject {
    convenience init(openHABRootUrl: String) {
        self.init()
        self.openHABRootUrl = openHABRootUrl
    }
}
