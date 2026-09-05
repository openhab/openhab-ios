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

/// Filters a flat, pre-flattened widget list to only those that should be displayed,
/// mirroring Android's visibility logic:
///   - widget.visibility == false → hidden
///   - frame with no visible direct children (including empty frames) → hidden
///   - widget whose nearest frame ancestor is hidden → hidden
func sitemapVisibleWidgets(_ widgets: [OpenHABWidget]) -> [OpenHABWidget] {
    var widgetsById: [String: OpenHABWidget] = [:]
    for widget in widgets {
        widgetsById[widget.widgetId] = widget
    }

    func shouldShow(_ widget: OpenHABWidget) -> Bool {
        guard widget.visibility else { return false }
        if widget.type == .frame {
            let children = widgets.filter { $0.parentWidgetId == widget.widgetId }
            if !children.contains(where: \.visibility) { return false }
        }
        guard let parentId = widget.parentWidgetId,
              let parent = widgetsById[parentId] else { return true }
        return shouldShow(parent)
    }

    return widgets.filter { shouldShow($0) }
}

@MainActor
extension SitemapPageViewModel {
    var relevantWidgets: [OpenHABWidget] {
        let widgets = currentPage?.widgets ?? []
        let visibleWidgets = sitemapVisibleWidgets(widgets)
        guard !searchText.isEmpty else { return visibleWidgets }
        return visibleWidgets.filter {
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
