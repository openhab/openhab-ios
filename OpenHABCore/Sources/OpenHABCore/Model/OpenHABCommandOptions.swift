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

public class OpenHABCommandOptions: Decodable {
    public var command = ""
    public var label: String? = ""

    public init(command: String = "", label: String = "") {
        self.command = command
        self.label = label
    }
}

extension OpenHABCommandOptions {
    convenience init?(_ options: Components.Schemas.CommandOption?) {
        if let options {
            self.init(command: options.command.orEmpty, label: options.label.orEmpty)
        } else {
            return nil
        }
    }
}
