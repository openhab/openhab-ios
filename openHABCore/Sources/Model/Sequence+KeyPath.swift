// Copyright (c) 2010-2021 Contributors to the openHAB project
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

public extension Sequence {
    func sorted<T: Comparable>(by keyPath: KeyPath<Element, T>, using comparator: (T, T) -> Bool = (<)) -> [Element] {
        sorted { a, b in
            comparator(a[keyPath: keyPath], b[keyPath: keyPath])
        }
    }

    func max<T: Comparable>(by keyPath: KeyPath<Element, T>) -> Element? {
        // swiftformat:disable:next redundantSelf
        self.max { a, b in
            a[keyPath: keyPath] < b[keyPath: keyPath]
        }
    }

    func min<T: Comparable>(by keyPath: KeyPath<Element, T>) -> Element? {
        // swiftformat:disable:next redundantSelf
        self.min { a, b in
            a[keyPath: keyPath] > b[keyPath: keyPath]
        }
    }

    func map<T>(_ keyPath: KeyPath<Element, T>) -> [T] {
        map { $0[keyPath: keyPath] }
    }
}
