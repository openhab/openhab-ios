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

import Combine
import OpenHABCore
import os.log

@MainActor
class PushRegistrationService: ObservableObject {
    // MARK: - Private state

    private var cancellables = Set<AnyCancellable>()
    private var networkObservationTask: Task<Void, Never>?
    private var apsDeviceToken: String?
    private var apsDeviceId: String?
    private var apsDeviceName: String?
    private var activeConnection: ConnectionInfo?

    init() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("apsRegistered"),
            object: nil,
            queue: nil
        ) { [weak self] note in
            let deviceToken = note.userInfo?["deviceToken"] as? String
            let deviceId = note.userInfo?["deviceId"] as? String
            let deviceName = note.userInfo?["deviceName"] as? String
            Task { @MainActor in
                self?.handleApsRegistration(deviceToken: deviceToken, deviceId: deviceId, deviceName: deviceName)
            }
        }

        networkObservationTask = Task { [weak self] in
            for await state in await NetworkTracker.shared.stateStream() {
                guard let activeConnection = state.activeConnection else { continue }
                self?.activeConnection = activeConnection
            }
        }
    }

    deinit {
        networkObservationTask?.cancel()
    }

    // MARK: - APS Registration

    private func handleApsRegistration(deviceToken: String?, deviceId: String?, deviceName: String?) {
        Logger.viewController.info("handleApsRegistration")
        apsDeviceToken = deviceToken
        apsDeviceId = deviceId
        apsDeviceName = deviceName
        subscribeToOpenhabConnectionChanges()
    }

    private func subscribeToOpenhabConnectionChanges() {
        struct UuidWithConnection: Hashable, Equatable {
            let uuid: UUID
            let connection: ConnectionConfiguration
        }

        let storedOpenHabConnections = Preferences.shared.$storedHomes
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .map { updatedPreferences in
                Set<UuidWithConnection>(updatedPreferences.compactMap { storedWithUuid in
                    let (uuid, homeConfig) = storedWithUuid
                    guard let connection = Preferences.shared.getNotificationConnection(of: homeConfig) else { return nil }
                    return UuidWithConnection(uuid: uuid, connection: connection)
                })
            }

        let connectionsWithPreviousValues = storedOpenHabConnections
            .scan((previous: Set<UuidWithConnection>(), current: Set<UuidWithConnection>())) { previous, current in
                (previous: previous.current, current: current)
            }

        let differences = connectionsWithPreviousValues.map { (previous, current) in
            (newValues: current.subtracting(previous), deletedValues: previous.subtracting(current))
        }

        differences.sink { [weak self] diff in
            Logger.viewController.info("openhabConnectionSubscription updated")
            for newHome in diff.newValues {
                Logger.viewController.info("openhabConnectionSubscription uuid \(newHome.uuid) registering for push notifications")
                self?.registerHome(uuid: newHome.uuid, connection: newHome.connection)
            }
            for deletedHome in diff.deletedValues {
                Logger.viewController.warning("APNS Deregistration is missing (wanted to deregister \(deletedHome.connection.url))")
            }
        }
        .store(in: &cancellables)
    }

    private func registerHome(uuid: UUID, connection: ConnectionConfiguration) {
        guard let deviceId = apsDeviceId,
              let deviceToken = apsDeviceToken,
              let deviceName = apsDeviceName else {
            Logger.viewController.fault("Cannot register homes for push notifications, no notification registration data available")
            return
        }
        Logger.viewController.info("Registering notifications with \(connection.url)")
        _ = registerHome(uuid, connection, deviceToken, deviceId, deviceName)
    }

    private func registerHome(_ uuid: UUID, _ config: ConnectionConfiguration, _ deviceToken: String, _ deviceId: String, _ deviceName: String) -> Task<Void, Never> {
        Task {
            do {
                let client = HTTPClient(connectionConfiguration: config)
                if let cloudUserId = try await client.register(prefsURL: config.url, deviceToken: deviceToken, deviceId: deviceId, deviceName: deviceName) {
                    Preferences.shared.setCloudUserId(cloudUserId, for: uuid)
                    Logger.viewController.info("my.openHAB registration succeeded with cloudUserId \(cloudUserId)")
                }
                Logger.viewController.info("my.openHAB registration succeeded without cloudUserId")
            } catch {
                Logger.viewController.error("my.openHAB registration failed \(error.localizedDescription)")
            }
        }
    }
}
