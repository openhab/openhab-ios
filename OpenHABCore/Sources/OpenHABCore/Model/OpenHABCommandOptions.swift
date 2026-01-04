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

import Foundation

public struct OpenHABCommandOptions: Decodable, Sendable {
    public var command = ""
    public var label: String? = ""

    public init(command: String = "", label: String = "") {
        self.command = command
        self.label = label
    }
}

extension OpenHABCommandOptions {
    init?(_ options: Components.Schemas.CommandOption?) {
        if let options {
            self.init(command: options.command.orEmpty, label: options.label.orEmpty)
        } else {
            return nil
        }
    }
}
