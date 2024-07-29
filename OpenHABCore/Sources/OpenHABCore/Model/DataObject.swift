// Copyright (c) 2010-2024 Contributors to the openHAB project
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

public protocol DataObject: AnyObject {
    var openHABRootUrl: String { get set }
    var openHABUsername: String { get set }
    var openHABPassword: String { get set }
    var openHABVersion: Int { get set }
    var openHABAlwaysSendCreds: Bool { get set }
}
