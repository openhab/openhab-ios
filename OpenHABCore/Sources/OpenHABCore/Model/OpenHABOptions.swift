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

public class OpenHABOptions: Decodable {
    public var value = ""
    public var label = ""

    public init(value: String = "", label: String = "") {
        self.value = value
        self.label = label
    }
}

extension OpenHABOptions {
    convenience init?(_ options: Components.Schemas.StateOption?) {
        if let options {
            self.init(value: options.value.orEmpty, label: options.label.orEmpty)
        } else {
            return nil
        }
    }
}
