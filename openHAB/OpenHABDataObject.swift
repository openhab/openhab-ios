// Copyright (c) 2010-2019 Contributors to the openHAB project
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

class OpenHABDataObject: NSObject, ObservableObject {
    var openHABRootUrl = ""
    var openHABUsername = ""
    var openHABPassword = ""
    #if !os(watchOS)
    var rootViewController: OpenHABViewController?
    #endif
    var openHABVersion: Int = 0
}
