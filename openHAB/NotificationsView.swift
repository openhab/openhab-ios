// Copyright (c) 2010-2025 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Kingfisher
import OpenHABCore
import os.log
import SwiftUI

struct NotificationRow: View {
    var notification: OpenHABNotification
    var connection: ConnectionInfo

    var body: some View {
        HStack {
            KFImage(iconUrl)
                .placeholder {
                    Image("openHABIcon").resizable()
                }
                .resizable()
                .frame(width: 40, height: 40)
                .cornerRadius(8)
            VStack(alignment: .leading) {
                Text(notification.message ?? "")
                    .font(.body)
                if let timeStamp = notification.created {
                    Text(dateString(from: timeStamp))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
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
            iconType: .png,
            iconColor: ""
        )

        guard let url = endpoint.url, url.scheme != nil else {
            Logger(subsystem: "org.openhab.app", category: "NotificationRow")
                .warning("Invalid icon URL for icon: \(notification.icon ?? "nil", privacy: .public)")
            return nil
        }

        return url
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}

typealias NotificationLoader = () async -> [OpenHABNotification]

struct NotificationsView<Tracker: NetworkTracking>: View where Tracker: ObservableObject {
    @ObservedObject var networkTracker: Tracker
    @State var notifications: [OpenHABNotification] = []
    let loadNotifications: NotificationLoader

    private let logger = Logger(subsystem: "org.openhab.app", category: "NotificationView")

    var body: some View {
        List(notifications, id: \.id) { notification in
            if let connection = networkTracker.activeConnection {
                NotificationRow(notification: notification, connection: connection)
            }
        }
        .refreshable {
            await notifications = loadNotifications()
        }
        .navigationTitle("Notifications")
        .task {
            await notifications = loadNotifications()
        }
    }
}

extension NotificationsView where Tracker == NetworkTracker {
    init(notifications: [OpenHABNotification] = []) {
        networkTracker = NetworkTracker.shared
        _notifications = State(initialValue: notifications)
        loadNotifications = {
            let logger = Logger(subsystem: "org.openhab.app", category: "NotificationView")

            do {
                guard let config = Preferences.getLowestPriorityOpenHABConnection() else {
                    logger.warning("No openHAB configuration found.")
                    return []
                }

                guard let url = URL(string: config.url), url.scheme != nil else {
                    logger.error("Invalid URL: \(config.url, privacy: .public)")
                    return []
                }

                let client = HTTPClient(configuration: config)
                return try await client.notification(urlString: config.url)
            } catch {
                logger.error("Failed to load notifications: \(error.localizedDescription, privacy: .public)")
                return []
            }
        }
    }
}

#if DEBUG
public extension ConnectionInfo {
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

final class MockNetworkTracker: NetworkTracking, ObservableObject {
    @Published var activeConnection: ConnectionInfo?

    init(connection: ConnectionInfo?) {
        activeConnection = connection
    }
}

struct NotificationsViewPreview: View {
    var body: some View {
        let mockTracker = MockNetworkTracker(connection: .mock)
        return NotificationsView(
            networkTracker: mockTracker,
            notifications: [],
            loadNotifications: {
                [
                    OpenHABNotification(
                        message: "Preview Notification 1",
                        created: .now,
                        icon: "sun",
                        id: UUID().uuidString
                    ),
                    OpenHABNotification(
                        message: "Preview Notification 2",
                        created: .now.addingTimeInterval(-3600),
                        icon: "moon",
                        id: UUID().uuidString
                    )
                ]
            }
        )
    }
}

#Preview {
    NotificationsViewPreview()
}
#endif
