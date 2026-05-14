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

import Observation
import SwiftUI

@MainActor
@Observable
final class ToastService {
    static let shared = ToastService()

    var isPresented = false
    var title = ""
    var message = ""
    var onTap: (() -> Void)?

    private init() {}

    func show(title: String, message: String, onTap: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.onTap = onTap
        isPresented = true
    }
}
