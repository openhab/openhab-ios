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

public class OpenHABCommandDescription {
    public var commandOptions: [OpenHABCommandOptions] = []

    public init(commandOptions: [OpenHABCommandOptions]?) {
        self.commandOptions = commandOptions ?? []
    }
}

public extension OpenHABCommandDescription {
    struct CodingData: Decodable {
        let commandOptions: [OpenHABCommandOptions]?
    }
}

extension OpenHABCommandDescription.CodingData {
    var openHABCommandDescription: OpenHABCommandDescription {
        OpenHABCommandDescription(commandOptions: commandOptions)
    }
}

extension OpenHABCommandDescription {
    convenience init?(_ commands: Components.Schemas.CommandDescription?) {
        if let commands {
            self.init(commandOptions: commands.commandOptions?.compactMap { OpenHABCommandOptions($0) })
        } else {
            return nil
        }
    }
}
