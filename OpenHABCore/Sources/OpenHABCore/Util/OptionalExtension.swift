// Copyright (c) 2010-2026 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

public extension Optional {
    /// True when there is no value, or the value matches `expression`, e.g.
    /// `loadingState.isNil(or: \.isFinished)`.
    func isNil(or expression: (Wrapped) -> Bool) -> Bool {
        map(expression) ?? true
    }
}

public extension Optional where Wrapped: Collection {
    /// True for `nil` and for an empty string, array or other collection.
    var isNilOrEmpty: Bool {
        isNil(or: \.isEmpty)
    }
}
