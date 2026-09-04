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
import os.log

@MainActor
public final class WidgetCommandDispatcher {
    private var pendingTasks: [String: Task<Void, Never>] = [:]

    /// When set, an `.immediate`-policy widget dispatch whose widget has a non-empty
    /// commandConfirmMessage is routed through this instead of sending directly -- it's expected
    /// to present a confirmation UI and call `proceed()` if the user confirms. Only `.immediate`
    /// is gated: `.debounce`/`.finalOnly`/`.pressRelease` back continuous-drag interactions
    /// (Slider, Setpoint, ColorPicker dragging), which can reach dispatch repeatedly during a
    /// single gesture -- confirming each one would prompt mid-drag. Confirming a continuous
    /// gesture once, up front, is a different UX pattern that isn't implemented here.
    public var confirmationHandler: ((_ message: String, _ proceed: @escaping () -> Void) -> Void)?

    public init() {}

    @MainActor
    public func send(_ command: String?,
                     for widget: OpenHABWidget,
                     policy: WidgetCommandPolicy,
                     phase: WidgetCommandPhase = .change,
                     key: String? = nil,
                     fallbackItem: OpenHABItem? = nil) {
        guard let command else { return }

        switch policy {
        case .immediate:
            dispatchConfirmingIfNeeded(command: command, for: widget, fallbackItem: fallbackItem)
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
                     for itemname: String,
                     policy: WidgetCommandPolicy,
                     phase: WidgetCommandPhase = .change,
                     key: String? = nil,
                     execute: @escaping @MainActor (_ itemname: String, _ command: String) -> Void) {
        guard let command, !itemname.isEmpty else { return }

        switch policy {
        case .immediate:
            execute(itemname, command)
        case let .debounce(duration):
            guard phase != .release else {
                execute(itemname, command)
                return
            }
            sendDebounced(
                command,
                for: itemname,
                duration: duration,
                key: key,
                execute: execute
            )
        case .finalOnly:
            guard phase == .release else { return }
            execute(itemname, command)
        case .pressRelease:
            guard phase == .press || phase == .release else { return }
            execute(itemname, command)
        }
    }

    @MainActor
    public func send(_ command: String?,
                     for item: OpenHABItem?,
                     policy: WidgetCommandPolicy,
                     phase: WidgetCommandPhase = .change,
                     key: String? = nil,
                     execute: @escaping @MainActor (_ itemname: String, _ command: String) -> Void) {
        guard let command, let item else { return }

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
        guard let command else { return }
        dispatch(command: command, for: widget, fallbackItem: fallbackItem)
    }

    @MainActor
    public func sendRelease(_ command: String?,
                            for widget: OpenHABWidget,
                            fallbackItem: OpenHABItem? = nil) {
        guard let command else { return }
        dispatch(command: command, for: widget, fallbackItem: fallbackItem)
    }

    @MainActor
    public func send(_ state: NumberState?,
                     for widget: OpenHABWidget,
                     fallbackItem: OpenHABItem? = nil) {
        guard let state else { return }
        send(state.commandString, for: widget, policy: .immediate, fallbackItem: fallbackItem)
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
    public func cancelPending(for itemname: String, key: String? = nil) {
        let taskKey = commandKey(for: itemname, key: key)
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
    private func sendDebounced(_ command: String,
                               for itemname: String,
                               duration: Duration,
                               key: String?,
                               execute: @escaping @MainActor (_ itemname: String, _ command: String) -> Void) {
        let taskKey = commandKey(for: itemname, key: key)
        pendingTasks[taskKey]?.cancel()
        pendingTasks[taskKey] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            execute(itemname, command)
            self?.pendingTasks.removeValue(forKey: taskKey)
        }
    }

    @MainActor
    private func dispatchConfirmingIfNeeded(command: String, for widget: OpenHABWidget, fallbackItem: OpenHABItem?) {
        guard let message = widget.commandConfirmMessage, !message.isEmpty, let confirmationHandler else {
            dispatch(command: command, for: widget, fallbackItem: fallbackItem)
            return
        }
        confirmationHandler(message) { [weak self] in
            self?.dispatch(command: command, for: widget, fallbackItem: fallbackItem)
        }
    }

    @MainActor
    private func dispatch(command: String, for widget: OpenHABWidget, fallbackItem: OpenHABItem?) {
        guard let item = widget.item ?? fallbackItem else {
            Logger.restAPI.info("Command for Item = nil")
            return
        }
        guard let sendCommand = widget.sendCommand else {
            Logger.restAPI.info("sendCommand closure not set")
            return
        }
        sendCommand(item, command)
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

    private func commandKey(for itemname: String, key: String?) -> String {
        if let key {
            return "\(itemname)-\(key)"
        }
        return itemname
    }

    deinit {
        pendingTasks.values.forEach { $0.cancel() }
        pendingTasks.removeAll()
    }
}
