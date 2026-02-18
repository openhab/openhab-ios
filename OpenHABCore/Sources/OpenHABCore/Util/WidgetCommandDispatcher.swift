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

@MainActor
public final class WidgetCommandDispatcher {
    private var pendingTasks: [String: Task<Void, Never>] = [:]

    public init() {}

    @MainActor
    public func send(_ command: String?,
                     for widget: OpenHABWidget,
                     policy: WidgetCommandPolicy,
                     phase: WidgetCommandPhase = .change,
                     key: String? = nil,
                     fallbackItem: OpenHABItem? = nil) {
        guard let command, !command.isEmpty else { return }

        switch policy {
        case .immediate:
            dispatch(command: command, for: widget, fallbackItem: fallbackItem)
        case let .debounce(duration):
            guard phase != .release else {
                dispatch(command: command, for: widget, fallbackItem: fallbackItem)
                return
            }
            sendDebounced(
                command,
                for: widget,
                duration: duration,
                key: key,
                fallbackItem: fallbackItem
            )
        case .finalOnly:
            guard phase == .release else { return }
            dispatch(command: command, for: widget, fallbackItem: fallbackItem)
        case .pressRelease:
            guard phase == .press || phase == .release else { return }
            dispatch(command: command, for: widget, fallbackItem: fallbackItem)
        }
    }

    @MainActor
    public func send(_ command: String?,
                     for item: OpenHABItem?,
                     policy: WidgetCommandPolicy,
                     phase: WidgetCommandPhase = .change,
                     key: String? = nil,
                     execute: @escaping @MainActor (_ itemname: String, _ command: String) -> Void) {
        guard let command, !command.isEmpty, let item else { return }

        switch policy {
        case .immediate:
            execute(item.name, command)
        case let .debounce(duration):
            guard phase != .release else {
                execute(item.name, command)
                return
            }
            sendDebounced(
                command,
                for: item,
                duration: duration,
                key: key,
                execute: execute
            )
        case .finalOnly:
            guard phase == .release else { return }
            execute(item.name, command)
        case .pressRelease:
            guard phase == .press || phase == .release else { return }
            execute(item.name, command)
        }
    }

    @MainActor
    public func sendPress(_ command: String?,
                          for widget: OpenHABWidget,
                          fallbackItem: OpenHABItem? = nil) {
        guard let command, !command.isEmpty else { return }
        dispatch(command: command, for: widget, fallbackItem: fallbackItem)
    }

    @MainActor
    public func sendRelease(_ command: String?,
                            for widget: OpenHABWidget,
                            fallbackItem: OpenHABItem? = nil) {
        guard let command, !command.isEmpty else { return }
        dispatch(command: command, for: widget, fallbackItem: fallbackItem)
    }

    @MainActor
    public func sendItemUpdate(_ state: NumberState?,
                               for widget: OpenHABWidget,
                               fallbackItem: OpenHABItem? = nil) {
        guard let state else { return }

        if let item = widget.item ?? fallbackItem,
           let sendCommand = widget.sendCommand {
            sendCommand(item, state.commandString)
            return
        }

        widget.sendItemUpdate(state: state)
    }

    @MainActor
    public func cancelPending(for widget: OpenHABWidget, key: String? = nil) {
        let taskKey = commandKey(for: widget, key: key)
        pendingTasks[taskKey]?.cancel()
        pendingTasks.removeValue(forKey: taskKey)
    }

    @MainActor
    public func cancelPending(for item: OpenHABItem, key: String? = nil) {
        let taskKey = commandKey(for: item, key: key)
        pendingTasks[taskKey]?.cancel()
        pendingTasks.removeValue(forKey: taskKey)
    }

    @MainActor
    private func sendDebounced(_ command: String,
                               for widget: OpenHABWidget,
                               duration: Duration,
                               key: String?,
                               fallbackItem: OpenHABItem?) {
        let taskKey = commandKey(for: widget, key: key)
        pendingTasks[taskKey]?.cancel()
        pendingTasks[taskKey] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.dispatch(command: command, for: widget, fallbackItem: fallbackItem)
            self?.pendingTasks.removeValue(forKey: taskKey)
        }
    }

    @MainActor
    private func sendDebounced(_ command: String,
                               for item: OpenHABItem,
                               duration: Duration,
                               key: String?,
                               execute: @escaping @MainActor (_ itemname: String, _ command: String) -> Void) {
        let taskKey = commandKey(for: item, key: key)
        pendingTasks[taskKey]?.cancel()
        pendingTasks[taskKey] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            execute(item.name, command)
            self?.pendingTasks.removeValue(forKey: taskKey)
        }
    }

    @MainActor
    private func dispatch(command: String, for widget: OpenHABWidget, fallbackItem: OpenHABItem?) {
        if let item = widget.item ?? fallbackItem,
           let sendCommand = widget.sendCommand {
            sendCommand(item, command)
            return
        }
        widget.sendCommand(command)
    }

    private func commandKey(for widget: OpenHABWidget, key: String?) -> String {
        if let key {
            return "\(widget.widgetId)-\(key)"
        }
        return widget.widgetId
    }

    private func commandKey(for item: OpenHABItem, key: String?) -> String {
        if let key {
            return "\(item.name)-\(key)"
        }
        return item.name
    }

    deinit {
        pendingTasks.values.forEach { $0.cancel() }
        pendingTasks.removeAll()
    }
}
