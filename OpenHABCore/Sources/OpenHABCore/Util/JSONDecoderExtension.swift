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

private enum ISO8601Tolerant {
    #if swift(>=6.2)
    static let strategies: [Date.ISO8601FormatStyle] = [
        .init(includingFractionalSeconds: true)
    ]
    #else
    static let strategies: [Date.ISO8601FormatStyle] = [
        .init(includingFractionalSeconds: false),
        .init(includingFractionalSeconds: true)
    ]
    #endif

    static func parse(_ string: String) -> Date? {
        for style in strategies {
            if let date = try? Date(string, strategy: style) { return date }
        }
        return nil
    }
}

public extension JSONDecoder {
    static func makeISO8601TolerantDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            if let date = ISO8601Tolerant.parse(dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode ISO8601 date string: \(dateString)"
            )
        }
        return decoder
    }
}
