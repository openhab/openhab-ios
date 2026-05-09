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

struct IconLoadDiagnosticsSnapshot {
    let resolutionFailures: Int
    let starts: Int
    let successes: Int
    let memoryHits: Int
    let diskHits: Int
    let networkLoads: Int
    let cancellations: Int
    let failures: Int
    let distinctURLs: Int
    let distinctRows: Int

    var isEmpty: Bool {
        resolutionFailures == 0 &&
            starts == 0 &&
            successes == 0 &&
            memoryHits == 0 &&
            diskHits == 0 &&
            networkLoads == 0 &&
            cancellations == 0 &&
            failures == 0
    }
}

actor IconLoadDiagnostics {
    static let shared = IconLoadDiagnostics()

    private var starts = 0
    private var resolutionFailures = 0
    private var successes = 0
    private var memoryHits = 0
    private var diskHits = 0
    private var networkLoads = 0
    private var cancellations = 0
    private var failures = 0
    private var distinctURLs: Set<String> = []
    private var distinctRows: Set<String> = []

    func recordResolutionFailure(rowIdentity: String) {
        resolutionFailures += 1
        distinctRows.insert(rowIdentity)
    }

    func recordStart(url: URL, rowIdentity: String) {
        starts += 1
        distinctURLs.insert(url.absoluteString)
        distinctRows.insert(rowIdentity)
    }

    func recordSuccess(url: URL, rowIdentity: String, cacheType: String) {
        successes += 1
        distinctURLs.insert(url.absoluteString)
        distinctRows.insert(rowIdentity)
        switch cacheType {
        case "memory":
            memoryHits += 1
        case "disk":
            diskHits += 1
        default:
            networkLoads += 1
        }
    }

    func recordCancellation(url: URL, rowIdentity: String) {
        cancellations += 1
        distinctURLs.insert(url.absoluteString)
        distinctRows.insert(rowIdentity)
    }

    func recordFailure(url: URL, rowIdentity: String) {
        failures += 1
        distinctURLs.insert(url.absoluteString)
        distinctRows.insert(rowIdentity)
    }

    func snapshotAndReset() -> IconLoadDiagnosticsSnapshot {
        let snapshot = IconLoadDiagnosticsSnapshot(
            resolutionFailures: resolutionFailures,
            starts: starts,
            successes: successes,
            memoryHits: memoryHits,
            diskHits: diskHits,
            networkLoads: networkLoads,
            cancellations: cancellations,
            failures: failures,
            distinctURLs: distinctURLs.count,
            distinctRows: distinctRows.count
        )
        resolutionFailures = 0
        starts = 0
        successes = 0
        memoryHits = 0
        diskHits = 0
        networkLoads = 0
        cancellations = 0
        failures = 0
        distinctURLs.removeAll(keepingCapacity: true)
        distinctRows.removeAll(keepingCapacity: true)
        return snapshot
    }
}

@MainActor
enum SitemapDiagnostics {
    private static let logger = Logger(subsystem: "org.openhab", category: "SitemapDiagnostics")

    static var isEnabled: Bool {
        Preferences.shared.applicationPreferences.sitemapDiagnosticsLogging
    }

    // swiftlint:disable:next function_parameter_count
    static func logUpdate(origin: PageUpdateOrigin,
                          widgetCount: Int,
                          rowCount: Int,
                          inputsChanged: Bool,
                          titleChanged: Bool,
                          reusedInputCount: Int,
                          changedRowCount: Int,
                          changedRowKinds: String,
                          analysisMs: Int,
                          buildRowInputsMs: Int,
                          applyStateMs: Int,
                          totalUpdateMs: Int) {
        guard isEnabled else { return }
        logger.info(
            "update origin=\(origin.rawValue, privacy: .public) widgets=\(widgetCount, privacy: .public) rows=\(rowCount, privacy: .public) inputsChanged=\(inputsChanged, privacy: .public) titleChanged=\(titleChanged, privacy: .public) reusedInputs=\(reusedInputCount, privacy: .public) changedRows=\(changedRowCount, privacy: .public) changedKinds=\(changedRowKinds, privacy: .public) buildRowInputsMs=\(buildRowInputsMs, privacy: .public) applyStateMs=\(applyStateMs, privacy: .public) analysisMs=\(analysisMs, privacy: .public) totalUpdateMs=\(totalUpdateMs, privacy: .public)"
        )
    }

    static func logLongPoll(requestMs: Int,
                            returnedPage: Bool,
                            status: String,
                            responseGapMs: Int?) {
        guard isEnabled else { return }
        logger.info(
            "longPoll requestMs=\(requestMs, privacy: .public) returnedPage=\(returnedPage, privacy: .public) status=\(status, privacy: .public) responseGapMs=\(responseGapMs ?? -1, privacy: .public)"
        )
    }

    static func logLongPollDebounce(action: String,
                                    elapsedMs: Int,
                                    remainingMs: Int,
                                    replacedPendingPage: Bool,
                                    coalescedUpdates: Int) {
        guard isEnabled else { return }
        logger.info(
            "longPollDebounce action=\(action, privacy: .public) elapsedMs=\(elapsedMs, privacy: .public) remainingMs=\(remainingMs, privacy: .public) replacedPendingPage=\(replacedPendingPage, privacy: .public) coalescedUpdates=\(coalescedUpdates, privacy: .public)"
        )
    }

    static func logIconSummary(_ snapshot: IconLoadDiagnosticsSnapshot) {
        guard isEnabled, !snapshot.isEmpty else { return }
        logger.info(
            "icons resolutionFailures=\(snapshot.resolutionFailures, privacy: .public) starts=\(snapshot.starts, privacy: .public) successes=\(snapshot.successes, privacy: .public) memoryHits=\(snapshot.memoryHits, privacy: .public) diskHits=\(snapshot.diskHits, privacy: .public) networkLoads=\(snapshot.networkLoads, privacy: .public) cancellations=\(snapshot.cancellations, privacy: .public) failures=\(snapshot.failures, privacy: .public) distinctURLs=\(snapshot.distinctURLs, privacy: .public) distinctRows=\(snapshot.distinctRows, privacy: .public)"
        )
    }

    static func logIconResolutionFailure(rowIdentity: String,
                                         icon: String,
                                         reason: String,
                                         trackerStatus: String,
                                         connectionDescription: String) {
        guard isEnabled else { return }
        logger.info(
            "iconResolutionFailure row=\(rowIdentity, privacy: .private(mask: .hash)) icon=\(icon, privacy: .public) reason=\(reason, privacy: .public) trackerStatus=\(trackerStatus, privacy: .public) connection=\(connectionDescription, privacy: .public)"
        )
    }

    static func logIconStart(rowIdentity: String, icon: String, url: URL, cacheKey: String) {
        guard isEnabled else { return }
        logger.debug(
            "iconStart row=\(rowIdentity, privacy: .private(mask: .hash)) icon=\(icon, privacy: .public) url=\(url.absoluteString, privacy: .public) cacheKey=\(cacheKey, privacy: .public)"
        )
    }

    static func logIconSuccess(rowIdentity: String, icon: String, url: URL, cacheType: String) {
        guard isEnabled else { return }
        logger.info(
            "iconSuccess row=\(rowIdentity, privacy: .private(mask: .hash)) icon=\(icon, privacy: .public) url=\(url.absoluteString, privacy: .public) cacheType=\(cacheType, privacy: .public)"
        )
    }

    static func logIconFailure(rowIdentity: String, icon: String, url: URL, reason: String, cancelled: Bool) {
        guard isEnabled else { return }
        logger.info(
            "iconFailure row=\(rowIdentity, privacy: .private(mask: .hash)) icon=\(icon, privacy: .public) url=\(url.absoluteString, privacy: .public) cancelled=\(cancelled, privacy: .public) reason=\(reason, privacy: .public)"
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
        let changedKinds: [String] = if newInputs.count == oldInputs.count {
            zip(newInputs, oldInputs)
                .compactMap { newInput, oldInput in
                    newInput != oldInput ? rowKind(for: newInput) : nil
                }
        } else {
            newInputs.map(rowKind(for:))
        }

        guard !changedKinds.isEmpty else { return "none" }

        let counts = changedKinds.reduce(into: [String: Int]()) { counts, kind in
            counts[kind, default: 0] += 1
        }

        return counts.keys
            .sorted()
            .map { kind in
                "\(kind):\(counts[kind, default: 0])"
            }
            .joined(separator: ",")
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
