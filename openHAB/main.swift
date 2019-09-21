//
//  main.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 21.09.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

// Inspired by https://marcosantadev.com/fake-appdelegate-unit-testing-swift/

import UIKit

let isRunningTests = NSClassFromString("XCTestCase") != nil
let appDelegateClass = isRunningTests ? nil : NSStringFromClass(AppDelegate.self)
let args = UnsafeMutableRawPointer(CommandLine.unsafeArgv).bindMemory(to: UnsafeMutablePointer<Int8>.self, capacity: Int(CommandLine.argc))
UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, appDelegateClass)
