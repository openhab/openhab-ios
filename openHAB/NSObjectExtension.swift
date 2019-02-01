//
//  NSObjectExtension.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 13.01.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation

extension NSObject {



    func getProperties(from classType: NSObject.Type) -> [String] {

        var propertiesCount : CUnsignedInt = 0
        let propertiesInAClass = class_copyPropertyList(classType, &propertiesCount)
        let propertiesArray : [String]

        for i in 0 ..< Int(propertiesCount) {
            let property = propertiesInAClass?[i]
            let strKey = NSString(utf8String: property_getName(property!)) as String?
            propertiesArray.append(strKey)

        }
        return propertiesArray
    }
}
