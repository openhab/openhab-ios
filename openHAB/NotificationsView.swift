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

    // App wide data access
    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

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
        if let appData {
            return Endpoint.icon(
                rootUrl: appData.openHABRootUrl,
                version: appData.openHABVersion,
                icon: notification.icon,
                state: "",
                iconType: .png,
                iconColor: ""
            ).url
        }
        return nil
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}

struct NotificationsView: View {
    private let logger = Logger(subsystem: "org.openhab.app", category: "NotificationView")

    @State var notifications: [OpenHABNotification] = []

    var body: some View {
        List(notifications, id: \.id) { notification in
            NotificationRow(notification: notification)
        }
        .refreshable {
            await notifications = loadNotifications()
        }
        .navigationTitle("Notifications")
        .task {
            await notifications = loadNotifications()
        }
    }

    init(notifications: [OpenHABNotification] = []) {
        _notifications = State(initialValue: notifications)
    }

    private func loadNotifications() async -> [OpenHABNotification] {
        do {
            guard let config = Preferences.getLowestPriorityOpenHABConnection() else { return [] }
            let client = HTTPClient(configuration: config)
            return try await client.notification(urlString: config.url)
        } catch {
            logger.error("\(error.localizedDescription)")
        }
        return []
    }
}

#Preview {
    NotificationsView(notifications: [
        OpenHABNotification(message: "message1", created: Date.now, id: UUID().uuidString),
        OpenHABNotification(message: "message2", created: Date.now, id: UUID().uuidString)
    ]
    )
}
