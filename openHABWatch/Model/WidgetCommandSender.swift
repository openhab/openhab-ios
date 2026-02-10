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

final class WidgetCommandSender {
    private var pendingTasks: [String: Task<Void, Never>] = [:]

    deinit {
        pendingTasks.values.forEach { $0.cancel() }
        pendingTasks.removeAll()
    }

    @MainActor
    func send(_ command: String?, for widget: OpenHABWidget, policy: WidgetCommandPolicy, key: String? = nil) {
        guard let command, !command.isEmpty else { return }
        switch policy {
        case .immediate:
            Logger.rowViews.info("Sending command immediately: \(command)")
            widget.sendCommand(command)
        case .debounce(let duration):
            sendDebounced(command, for: widget, duration: duration, key: key)
        }
    }

    @MainActor
    func sendPress(_ command: String?, for widget: OpenHABWidget) {
        guard let command, !command.isEmpty else { return }
        Logger.rowViews.info("Sending press command: \(command)")
        widget.sendCommand(command)
    }

    @MainActor
    func sendRelease(_ command: String?, for widget: OpenHABWidget) {
        guard let command, !command.isEmpty else { return }
        Logger.rowViews.info("Sending release command: \(command)")
        widget.sendCommand(command)
    }

    @MainActor
    func sendItemUpdate(_ state: NumberState?, for widget: OpenHABWidget) {
        guard state != nil else { return }
        Logger.rowViews.info("Sending item update")
        widget.sendItemUpdate(state: state)
    }

    @MainActor
    func cancelPending(for widget: OpenHABWidget, key: String? = nil) {
        let taskKey = commandKey(for: widget, key: key)
        pendingTasks[taskKey]?.cancel()
        pendingTasks.removeValue(forKey: taskKey)
    }

    @MainActor
    private func sendDebounced(_ command: String,
                               for widget: OpenHABWidget,
                               duration: Duration,
                               key: String?) {
        let taskKey = commandKey(for: widget, key: key)
        pendingTasks[taskKey]?.cancel()
        pendingTasks[taskKey] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            Logger.rowViews.info("Sending debounced command: \(command)")
            widget.sendCommand(command)
            self?.pendingTasks.removeValue(forKey: taskKey)
        }
    }

    @MainActor
    private func commandKey(for widget: OpenHABWidget, key: String?) -> String {
        if let key {
            return "\(widget.widgetId)-\(key)"
        }
        return widget.widgetId
    }
}
