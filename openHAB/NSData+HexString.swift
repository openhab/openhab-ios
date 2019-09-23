//  Converted to Swift 4 by Swiftify v4.2.20229 - https://objectivec2swift.com/
//
//  NSData+NSData_HexString.h
//  openHAB
//
//  Created by Victor Belov on 05/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

import Foundation

extension Data {
    /// A hexadecimal string representation of the bytes.
    func hexString() -> String {
        let hexDigits = Array("0123456789abcdef".utf16)
        var hexChars = [UTF16.CodeUnit]()
        hexChars.reserveCapacity(count * 2)

        for byte in self {
            let (index1, index2) = Int(byte).quotientAndRemainder(dividingBy: 16)
            hexChars.append(hexDigits[index1])
            hexChars.append(hexDigits[index2])
        }

        return String(utf16CodeUnits: hexChars, count: hexChars.count)
    }
}
