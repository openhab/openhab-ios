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
import CommonUI
import Kingfisher
import OpenHABCore
import os.log
import SFSafeSymbols
import SwiftUI

typealias NotificationLoader = () async -> [OpenHABNotification]

struct NotificationRow: View {
    @State var notification: OpenHABNotification
    @State var connection: ConnectionInfo

    var body: some View {
        HStack {
            KFImage(iconUrl)
                .withOpenHABCredentials(for: connection)
                .placeholder {
                    Image("openHABIcon").resizable()
                }
                .resizable()
                .frame(width: 40, height: 40)
                .clipShape(.rect(cornerRadius: 8))
            VStack(alignment: .leading) {
                Text(notification.message ?? "")
                    .font(.body)
                if let timeStamp = notification.created {
                    Text(dateString(from: timeStamp))
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                Text(notification.payload?.tag ?? "")
            }
        }

        .padding(.vertical, 8)
    }

    private var iconUrl: URL? {
        let endpoint = Endpoint.icon(
            rootUrl: connection.configuration.url,
            version: connection.version,
            icon: notification.icon,
            state: "",
            iconType: .svg,
            iconColor: ""
        )

        guard let url = endpoint?.url, url.scheme != nil else {
            Logger.viewController
                .warning("Invalid icon URL for icon: \(notification.icon ?? "nil", privacy: .public)")
            return nil
        }

        return url
    }

    private func dateString(from date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

#if DEBUG

@MainActor
class MockNetworkTracker: NetworkTracking, ObservableObject {
    @Published var activeConnection: ConnectionInfo?

    init(connection: ConnectionInfo?) {
        activeConnection = connection
    }
}

struct NotificationsViewPreview: View {
    var body: some View {
        let mockTracker = MockNetworkTracker(connection: .mock)
        return NotificationsView(networkTracker: mockTracker, notifications: []) {
            [
                OpenHABNotification(
                    id: UUID().uuidString,
                    message: "Preview Notification 1",
                    icon: "sun",
                    created: .now,
                    v: 0
                ),
                OpenHABNotification(
                    id: UUID().uuidString,
                    message: "Preview Notification 2",
                    icon: "moon",
                    created: .now.addingTimeInterval(-3600),
                    v: 1
                )
            ]
        }
    }
}

#endif

@MainActor
protocol NetworkTracking {
    var activeConnection: ConnectionInfo? { get }
}

struct NotificationsView<Tracker: NetworkTracking & ObservableObject>: View {
    @ObservedObject var networkTracker: Tracker
    @State var notifications: [OpenHABNotification] = []
    let loadNotifications: NotificationLoader
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(notifications, id: \.id) { notification in
            if let connection = networkTracker.activeConnection {
                NotificationRow(notification: notification, connection: connection)
            }
        }
        .refreshable {
            await notifications = loadNotifications()
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("Notifications")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    dismiss()
                }, label: {
                    Image(systemSymbol: .chevronBackward)
                        .accessibilityLabel("Back")
                })
            }
        }
        .task {
            await notifications = loadNotifications()
        }
    }
}

extension NotificationsView where Tracker == MainActorNetworkTracker {
    init(notifications: [OpenHABNotification] = []) {
        networkTracker = MainActorNetworkTracker.shared
        _notifications = State(initialValue: notifications)
        loadNotifications = {
            do {
                guard let config = Preferences.shared.getNotificationConnection() else {
                    Logger.notificationService.warning("No openHAB configuration found.")
                    return []
                }

                guard let url = URL(string: config.url), url.scheme != nil else {
                    Logger.notificationService.error("Invalid URL: \(config.url, privacy: .public)")
                    return []
                }

                let client = HTTPClient(connectionConfiguration: config)
                return try await client.notifications(urlString: config.url)
            } catch {
                Logger.notificationService.error("Failed to load notifications: \(error.localizedDescription, privacy: .public)")
                return []
            }
        }
    }
}

extension MainActorNetworkTracker: NetworkTracking {}

#if DEBUG
extension ConnectionInfo {
    static var mock: ConnectionInfo {
        ConnectionInfo(
            configuration: ConnectionConfiguration(
                url: "http://mock.local:8080",
                username: "demo",
                password: "demo",
                alwaysSendBasicAuth: true
            ),
            version: 3
        )
    }
}

#Preview {
    NotificationsViewPreview()
}
#endif
