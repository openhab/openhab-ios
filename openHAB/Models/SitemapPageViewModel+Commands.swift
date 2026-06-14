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
import os.log
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "org.openhab.app", category: "SitemapPageViewModel")

@MainActor
extension SitemapPageViewModel {
    func sendCommand(_ command: String?,
                     for widget: OpenHABWidget,
                     policy: WidgetCommandPolicy = .immediate,
                     phase: WidgetCommandPhase = .change,
                     key: String? = nil,
                     fallbackItem: OpenHABItem? = nil) {
        commandDispatcher.send(
            command,
            for: widget,
            policy: policy,
            phase: phase,
            key: key,
            fallbackItem: fallbackItem
        )
    }

    func cancelPendingCommand(for widget: OpenHABWidget, key: String? = nil) {
        commandDispatcher.cancelPending(for: widget, key: key)
    }

    func cancelPendingCommand(for item: OpenHABItem, key: String? = nil) {
        commandDispatcher.cancelPending(for: item, key: key)
    }

    func cancelPendingCommand(for itemname: String, key: String? = nil) {
        commandDispatcher.cancelPending(for: itemname, key: key)
        if key == nil {
            queuedCommands.removeValue(forKey: itemname)
            clearSliderOverride(for: itemname)
            if case .queued = commandStates[itemname] {
                setCommandState(.idle, for: itemname)
            }
        }
    }

    func sendCommand(_ command: String?,
                     for itemname: String,
                     policy: WidgetCommandPolicy = .immediate,
                     phase: WidgetCommandPhase = .change,
                     key: String? = nil) {
        commandDispatcher.send(
            command,
            for: itemname,
            policy: policy,
            phase: phase,
            key: key
        ) { [weak self] itemname, command in
            self?.sendCommand(itemname: itemname, command: command, origin: .command)
        }
    }

    func sendCommand(_ item: OpenHABItem?, commandToSend command: String?) {
        commandDispatcher.send(command, for: item, policy: .immediate, phase: .change) { [weak self] itemname, command in
            self?.sendCommand(itemname: itemname, command: command, origin: .command)
        }
    }

    func sendCommand(itemname: String, command: String) {
        sendCommand(itemname: itemname, command: command, origin: .command)
    }

    func sendToUpdate(item: OpenHABItem?,
                      state: NumberState?,
                      policy: WidgetCommandPolicy = .immediate,
                      phase: WidgetCommandPhase = .change,
                      key: String? = nil) {
        guard let item, let state else {
            logger.info("ItemUpdate for Item or State = nil")
            return
        }
        let command = state.commandString
        commandDispatcher.send(command, for: item, policy: policy, phase: phase, key: key) { [weak self] itemname, command in
            self?.sendCommand(itemname: itemname, command: command, origin: .update)
        }
    }

    func sendToUpdate(itemname: String,
                      state: NumberState?,
                      policy: WidgetCommandPolicy = .immediate,
                      phase: WidgetCommandPhase = .change,
                      key: String? = nil) {
        guard !itemname.isEmpty, let state else {
            logger.info("ItemUpdate for itemname or state = nil")
            return
        }
        let command = state.commandString
        commandDispatcher.send(command, for: itemname, policy: policy, phase: phase, key: key) { [weak self] itemname, command in
            self?.sendCommand(itemname: itemname, command: command, origin: .update)
        }
    }

    func flushQueuedCommands() {
        guard trackerStatus == .connected, !queuedCommands.isEmpty else { return }
        let queued = queuedCommands
        queuedCommands.removeAll()
        for (itemname, queuedCommand) in queued {
            guard commandStateVersions[itemname] == queuedCommand.version else { continue }
            sendCommandNow(itemname: itemname, command: queuedCommand.command, version: queuedCommand.version)
        }
    }

    func sendCommand(itemname: String, command: String, origin: CommandSendOrigin) {
        logger.debug("Dispatching command origin=\(origin.rawValue, privacy: .public), item=\(itemname, privacy: .public), command=\(command, privacy: .private(mask: .hash))")
        let version = nextCommandVersion(for: itemname)
        if trackerStatus != .connected {
            queuedCommands[itemname] = QueuedCommand(command: command, version: version)
            setCommandState(.queued, for: itemname)
            return
        }
        sendCommandNow(itemname: itemname, command: command, version: version)
    }

    func sendCommandNow(itemname: String, command: String, version: Int) {
        setCommandState(.sending, for: itemname)
        let deviceId = UIDevice.current.identifierForVendor?.uuidString
        let sourcePrefix = pageId.isEmpty ? nil : "org.openhab.ui.basic$\(defaultSitemap):\(pageId)"
        Task { [weak self] in
            guard let self else { return }
            do {
                try await openAPIService?.sendItemCommand(
                    itemname: itemname,
                    command: command,
                    sourcePrefix: sourcePrefix,
                    deviceId: deviceId
                )
                logger.info("Successfully sent command \(command, privacy: .private(mask: .hash)) to \(itemname, privacy: .public)")
                handleCommandSuccess(for: itemname, version: version)
            } catch {
                logger.info("Failed to send command \(command, privacy: .private(mask: .hash)) to \(itemname, privacy: .public): \(error.localizedDescription, privacy: .public)")
                handleCommandFailure(for: itemname, version: version, errorDescription: error.localizedDescription)
            }
        }
    }
}

@MainActor
extension SitemapPageViewModel {
    func nextCommandVersion(for itemname: String) -> Int {
        let newVersion = (commandStateVersions[itemname] ?? 0) + 1
        commandStateVersions[itemname] = newVersion
        return newVersion
    }

    func setCommandState(_ state: WidgetCommandLifecycleState, for itemname: String) {
        commandStateResetTasks[itemname]?.cancel()
        commandStateResetTasks[itemname] = nil

        switch state {
        case .idle:
            commandStates.removeValue(forKey: itemname)
        case .queued, .sending, .failed:
            commandStates[itemname] = state
        }
    }

    func handleCommandSuccess(for itemname: String, version: Int) {
        guard commandStateVersions[itemname] == version else { return }
        scheduleCommandStateReset(for: itemname, version: version, after: .milliseconds(450))
        scheduleSliderOverrideResetFallback(for: itemname, version: version, after: .seconds(1))
    }

    func handleCommandFailure(for itemname: String, version: Int, errorDescription: String) {
        guard commandStateVersions[itemname] == version else { return }
        clearSliderOverride(for: itemname)
        setCommandState(.failed(message: errorDescription), for: itemname)
    }

    func scheduleCommandStateReset(for itemname: String, version: Int, after delay: Duration) {
        commandStateResetTasks[itemname]?.cancel()
        commandStateResetTasks[itemname] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard let self else { return }
            guard commandStateVersions[itemname] == version else { return }
            setCommandState(.idle, for: itemname)
        }
    }

    func scheduleSliderOverrideResetFallback(for itemname: String, version: Int, after delay: Duration) {
        sliderOverrideResetTasks[itemname]?.cancel()
        sliderOverrideResetTasks[itemname] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard let self else { return }
            guard commandStateVersions[itemname] == version else { return }
            clearSliderOverride(for: itemname)
        }
    }

    func clearSliderOverride(for itemname: String) {
        guard sliderValueOverrides[itemname] != nil else { return }
        sliderOverrideResetTasks[itemname]?.cancel()
        sliderOverrideResetTasks[itemname] = nil
        objectWillChange.send()
        sliderValueOverrides.removeValue(forKey: itemname)
    }
}
