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

extension NSObject {
    func getProperties(from classType: NSObject.Type) -> [String] {
        var propertiesCount: CUnsignedInt = 0
        let propertiesInAClass = class_copyPropertyList(classType, &propertiesCount)
        let propertiesArray: [String]

        for i in 0 ..< Int(propertiesCount) {
            let property = propertiesInAClass?[i]
            let strKey = NSString(utf8String: property_getName(property!)) as String?
            propertiesArray.append(strKey)
        }
        return propertiesArray
    }
}
