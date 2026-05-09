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

import OpenHABCore

@MainActor
extension SitemapPageViewModel {
    var relevantWidgets: [OpenHABWidget] {
        let widgets = currentPage?.widgets ?? []
        guard !searchText.isEmpty else { return widgets }
        return widgets.filter {
            $0.label.lowercased().contains(searchText.lowercased()) && $0.type != .frame
        }
    }

    var commandLifecycleSummary: CommandLifecycleSummary {
        let failedCount = commandStates.values.reduce(into: 0) { result, state in
            if case .failed = state {
                result += 1
            }
        }
        if failedCount > 0 {
            return .failed(count: failedCount)
        }

        let sendingCount = commandStates.values.reduce(into: 0) { result, state in
            if case .sending = state {
                result += 1
            }
        }
        if sendingCount > 0 {
            return .sending(count: sendingCount)
        }
        return .idle
    }

    var sitemapInteractionSummary: SitemapInteractionSummary {
        if case let .failed(count) = commandLifecycleSummary {
            return .failed(count: count)
        }

        let queuedCount = commandStates.values.reduce(into: 0) { result, state in
            if case .queued = state {
                result += 1
            }
        }
        if queuedCount > 0 {
            return .queued(count: queuedCount)
        }

        switch trackerStatus {
        case .connected:
            if case let .sending(count) = commandLifecycleSummary {
                return .sending(count: count)
            }
            return .onlineIdle
        case .started, .connecting:
            return .connecting
        case .stopped:
            return .offline
        }
    }

    func rowInteractionState(for itemname: String?) -> RowInteractionState {
        guard let itemname, !itemname.isEmpty else { return .idle }

        if let lifecycleState = commandStates[itemname] {
            switch lifecycleState {
            case .queued:
                return .queued
            case .sending:
                return .sending
            case .failed:
                return .failed
            case .idle:
                break
            }
        }

        return trackerStatus == .connected ? .idle : .offline
    }
}
