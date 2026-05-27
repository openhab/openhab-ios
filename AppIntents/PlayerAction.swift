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

import AppIntents
import Foundation

@available(iOS 17.0, macOS 14.0, *)
enum PlayerAction: String, AppEnum {
    case play = "PLAY"
    case pause = "PAUSE"
    case next = "NEXT"
    case previous = "PREVIOUS"
    case rewind = "REWIND"
    case fastforward = "FASTFORWARD"

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Player Action")

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .play: DisplayRepresentation(title: "Play", synonyms: ["Start", "Resume", "Begin"]),
        .pause: DisplayRepresentation(title: "Pause", synonyms: ["Stop", "Hold", "Suspend"]),
        .next: DisplayRepresentation(title: "Next", synonyms: ["Skip", "Skip forward", "Next track"]),
        .previous: DisplayRepresentation(title: "Previous", synonyms: ["Back", "Skip back", "Previous track"]),
        .rewind: DisplayRepresentation(title: "Rewind", synonyms: ["Rewind back", "Go backward", "Replay"]),
        .fastforward: DisplayRepresentation(title: "Fast Forward", synonyms: ["Speed up", "Skip ahead", "FF"])
    ]
}

@available(iOS 17.0, macOS 14.0, *)
extension PlayerAction: CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .play: "Play"
        case .pause: "Pause"
        case .next: "Next"
        case .previous: "Previous"
        case .rewind: "Rewind"
        case .fastforward: "Fast Forward"
        }
    }
}
