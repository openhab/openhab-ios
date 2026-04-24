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
import OpenHABCore
import os.log

@MainActor
enum SitemapDiagnostics {
    private static let logger = Logger(subsystem: "org.openhab", category: "SitemapDiagnostics")

    static var isEnabled: Bool {
        Preferences.shared.applicationPreferences.sitemapDiagnosticsLogging
    }

    static func logUpdate(
        origin: PageUpdateOrigin,
        widgetCount: Int,
        rowCount: Int,
        inputsChanged: Bool,
        titleChanged: Bool,
        reusedInputCount: Int,
        changedRowCount: Int,
        changedRowKinds: String,
        analysisMs: Int
    ) {
        guard isEnabled else { return }
        logger.info(
            """
            update origin=\(origin.rawValue, privacy: .public) widgets=\(widgetCount, privacy: .public) rows=\(rowCount, privacy: .public) \
            inputsChanged=\(inputsChanged, privacy: .public) titleChanged=\(titleChanged, privacy: .public) \
            reusedInputs=\(reusedInputCount, privacy: .public) \
            changedRows=\(changedRowCount, privacy: .public) changedKinds=\(changedRowKinds, privacy: .public) \
            analysisMs=\(analysisMs, privacy: .public)
            """
        )
    }

    static func logPublishedRows(rowCount: Int, changedRowCount: Int) {
        guard isEnabled else { return }
        logger.info("rowInputs published rows=\(rowCount, privacy: .public) changedRows=\(changedRowCount, privacy: .public)")
    }

    static func logRender(kind: String, identity: String, detail: String = "") {
        guard isEnabled else { return }
        logger.debug("render kind=\(kind, privacy: .public) identity=\(identity, privacy: .private(mask: .hash)) detail=\(detail, privacy: .public)")
    }

    static func changedRowKinds(from oldInputs: [SitemapRowInput], to newInputs: [SitemapRowInput]) -> String {
        let changedKinds: [String]
        if newInputs.count == oldInputs.count {
            changedKinds = zip(newInputs, oldInputs)
                .compactMap { newInput, oldInput in
                    newInput != oldInput ? rowKind(for: newInput) : nil
                }
        } else {
            changedKinds = newInputs.map(rowKind(for:))
        }

        guard !changedKinds.isEmpty else { return "none" }

        let counts = changedKinds.reduce(into: [String: Int]()) { counts, kind in
            counts[kind, default: 0] += 1
        }

        return counts.keys.sorted().map { kind in
            "\(kind):\(counts[kind, default: 0])"
        }.joined(separator: ",")
    }

    static func rowKind(for input: SitemapRowInput) -> String {
        switch input {
        case .frame: "frame"
        case .linked: "linked"
        case .text: "text"
        case .slider: "slider"
        case .selection: "selection"
        case .segmented: "segmented"
        case .setpoint: "setpoint"
        case .rollershutter: "rollershutter"
        case .toggle: "toggle"
        case .input: "input"
        case .colorPicker: "colorPicker"
        case .media: "media"
        case .colorTemperature: "colorTemperature"
        case .buttonGrid: "buttonGrid"
        case .generic: "generic"
        }
    }
}
