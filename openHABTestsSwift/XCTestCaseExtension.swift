//
//  XCTestCaseExtension.swift
//  openHABTestsSwift
//
//  Created by Tim Müller-Seydlitz on 11.06.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation
import XCTest

// Inspired by https://www.swiftbysundell.com/posts/avoiding-force-unwrapping-in-swift-unit-tests
extension XCTestCase {
    // We conform to LocalizedError in order to be able to output
    // a nice error message.
    private struct RequireError<T>: LocalizedError {
        let file: StaticString
        let line: UInt

        // It's important to implement this property, otherwise we won't
        // get a nice error message in the logs if our tests start to fail.
        var errorDescription: String? {
            return "😱 Required value of type \(T.self) was nil at line \(line) in file \(file)."
        }
    }

    // Using file and line lets us automatically capture where
    // the expression took place in our source code.
    func require<T>(_ expression: @autoclosure () -> T?,
                    file: StaticString = #file,
                    line: UInt = #line) throws -> T {
        guard let value = expression() else {
            throw RequireError<T>(file: file, line: line)
        }

        return value
    }
}
