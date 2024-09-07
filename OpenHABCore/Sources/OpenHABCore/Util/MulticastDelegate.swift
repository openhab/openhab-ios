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

/**
 See https://www.vadimbulavin.com/multicast-delegate/
 */
public class MulticastDelegate<T> {
    private let delegates: NSHashTable<AnyObject> = NSHashTable.weakObjects()

    public init() {}

    public func add(_ delegate: T) {
        delegates.add(delegate as AnyObject)
    }

    public func remove(_ delegateToRemove: T) {
        for delegate in delegates.allObjects.reversed() where delegate === delegateToRemove as AnyObject {
            delegates.remove(delegate)
        }
    }

    public func invoke(_ invocation: (T) -> Void) {
        for delegate in delegates.allObjects.reversed() {
            invocation(delegate as! T)
        }
    }
}
