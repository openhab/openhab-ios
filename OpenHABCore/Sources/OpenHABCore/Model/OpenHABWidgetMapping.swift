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

public struct OpenHABWidgetMapping: Decodable, Sendable {
    public var command = ""
    public var label = ""
    public var row: Int?
    public var column: Int?
    public var icon: String?
    public var releaseCommand: String?

    /// Returns true if this mapping has press-and-release behavior
    public var hasPressReleaseBehavior: Bool {
        guard let releaseCommand else { return false }
        return !releaseCommand.isEmpty
    }

    public init(command: String?, label: String?, row: Int? = nil, column: Int? = nil, icon: String? = nil, releaseCommand: String? = nil) {
        self.command = command.orEmpty
        self.label = label.orEmpty
        self.row = row
        self.column = column
        self.icon = icon
        self.releaseCommand = releaseCommand
    }
}

extension OpenHABWidgetMapping {
    init(_ mapping: Components.Schemas.MappingDTO) {
        self.init(command: mapping.command, label: mapping.label, row: mapping.row.map { Int($0) }, column: mapping.column.map { Int($0) }, icon: mapping.icon, releaseCommand: mapping.releaseCommand)
    }
}
