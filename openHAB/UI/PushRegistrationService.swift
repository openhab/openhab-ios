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
    private struct UuidWithConnection: Hashable, Equatable {
        let uuid: UUID
        // not only URL, because auth and certs might be relevant for establishing the connection
        let connection: ConnectionConfiguration

        /// cloudUserId is written back by a successful registration, so comparing it would make
        /// every registration look like a configuration change and register a second time.
        private var identity: ConnectionConfiguration {
            var identity = connection
            identity.cloudUserId = nil
            return identity
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.uuid == rhs.uuid && lhs.identity == rhs.identity
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(uuid)
            hasher.combine(identity)
        }
    }

    // MARK: - Private state

    private var networkObservationTask: Task<Void, Never>?
    private var storedHomesTask: Task<Void, Never>?
    private var apsDeviceToken: String?
    private var apsDeviceId: String?
    private var apsDeviceName: String?
    private var activeConnection: ConnectionInfo?

    /// Connections that are currently configured for notifications.
    private var knownConnections = Set<UuidWithConnection>()
    /// Connections already registered with the cloud for the current `apsDeviceToken`.
    private var registeredConnections = Set<UuidWithConnection>()

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
                guard let activeConnection = state.activeConnection, let self else { continue }
                guard activeConnection != self.activeConnection else { continue }
                self.activeConnection = activeConnection
                registerPendingConnections()
            }
        }

        // Tracked independently of the push token, so a home added in a later session still
        // registers. Whichever of the two arrives second, `registerPendingConnections` joins them.
        subscribeToOpenhabConnectionChanges()
    }

    deinit {
        networkObservationTask?.cancel()
        storedHomesTask?.cancel()
    }

    // MARK: - APS Registration

    private func handleApsRegistration(deviceToken: String?, deviceId: String?, deviceName: String?) {
        Logger.viewController.info("handleApsRegistration")
        if deviceToken != apsDeviceToken {
            // A new device token invalidates every registration made with the previous one.
            registeredConnections.removeAll()
        }
        apsDeviceToken = deviceToken
        apsDeviceId = deviceId
        apsDeviceName = deviceName
        registerPendingConnections()
    }

    private func subscribeToOpenhabConnectionChanges() {
        storedHomesTask?.cancel()
        storedHomesTask = Task { @MainActor [weak self] in
            var debounceTask: Task<Void, Never>?

            for await storedHomes in await Preferences.shared.storedHomesStream {
                debounceTask?.cancel()
                let capturedHomes = storedHomes
                debounceTask = Task { @MainActor [weak self] in
                    // avoid overexcited registrations / deregistrations in batch updates
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled, let self else { return }
                    await self.updateKnownConnections(from: capturedHomes)
                }
            }
            debounceTask?.cancel()
        }
    }

    private func updateKnownConnections(from storedHomes: [UUID: HomePreferences]) async {
        var currentConnections = Set<UuidWithConnection>()
        for uuid in storedHomes.keys {
            // The persisted record carries no credentials, they live in the Keychain. Using it
            // raw authenticates against the cloud with an empty username and password.
            guard let homeConfig = await Preferences.shared.storedHomeWithCredentials(forId: uuid),
                  let connection = Preferences.getNotificationConnection(of: homeConfig) else { continue }
            currentConnections.insert(UuidWithConnection(uuid: uuid, connection: connection))
        }
        guard !Task.isCancelled else { return }

        let deletedValues = knownConnections.subtracting(currentConnections)
        knownConnections = currentConnections
        // Anything no longer configured must not count as registered any more, so that a home
        // coming back later is registered again.
        registeredConnections.formIntersection(currentConnections)

        Logger.viewController.info("openhabConnectionSubscription updated")
        for deletedHome in deletedValues {
            Logger.viewController.warning("APNS Deregistration is missing (wanted to deregister \(deletedHome.connection.url))")
        }
        registerPendingConnections()
    }

    /// Registers every known connection not yet registered with the current device token.
    /// Waits if no registration data is available, `handleApsRegistration` runs it again.
    private func registerPendingConnections() {
        let pendingConnections = knownConnections.subtracting(registeredConnections)
        guard !pendingConnections.isEmpty else { return }

        guard let deviceId = apsDeviceId,
              let deviceToken = apsDeviceToken,
              let deviceName = apsDeviceName else {
            Logger.viewController.info("Deferring push notification registration of \(pendingConnections.count) home(s), no notification registration data available yet")
            return
        }

        for pendingHome in pendingConnections {
            registeredConnections.insert(pendingHome)
            Logger.viewController.info("Registering notifications for home \(pendingHome.uuid) with \(pendingHome.connection.url)")
            _ = registerHome(pendingHome.uuid, pendingHome.connection, deviceToken, deviceId, deviceName)
        }
    }

    private func registerHome(_ uuid: UUID, _ config: ConnectionConfiguration, _ deviceToken: String, _ deviceId: String, _ deviceName: String) -> Task<Void, Never> {
        Task {
            do {
                let client = HTTPClient(connectionConfiguration: config)
                if let cloudUserId = try await client.register(prefsURL: config.url, deviceToken: deviceToken, deviceId: deviceId, deviceName: deviceName) {
                    await Preferences.shared.setCloudUserId(cloudUserId, for: uuid)
                    Logger.viewController.info("my.openHAB registration succeeded with cloudUserId \(cloudUserId)")
                } else {
                    Logger.viewController.info("my.openHAB registration succeeded without cloudUserId")
                }
            } catch {
                let detail = (error as? URLError).map { "URLError \($0.errorCode)" } ?? String(describing: error)
                Logger.viewController.error("my.openHAB registration failed for \(config.url): \(error.localizedDescription) (\(detail))")
                // Retried when the active connection changes, see networkObservationTask.
                registeredConnections.remove(UuidWithConnection(uuid: uuid, connection: config))
            }
        }
    }
}
