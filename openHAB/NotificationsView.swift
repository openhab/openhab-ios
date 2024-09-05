// Copyright (c) 2010-2024 Contributors to the openHAB project
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

struct NotificationsView: View {
    @State var notifications: [OpenHABNotification] = []

    var body: some View {
        List(notifications, id: \.id) { notification in
            NotificationRow(notification: notification)
        }
        .refreshable {
            loadNotifications()
        }
        .navigationTitle("Notifications")
        .onAppear {
            loadNotifications()
        }
    }

    private func loadNotifications() {
        NetworkConnection.notification(urlString: Preferences.remoteUrl) { response in
            DispatchQueue.main.async {
                switch response.result {
                case let .success(data):
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)
                        let codingDatas = try data.decoded(as: [OpenHABNotification.CodingData].self, using: decoder)
                        notifications = codingDatas.map(\.openHABNotification)
                    } catch {
                        os_log("%{PUBLIC}@ ", log: .default, type: .error, error.localizedDescription)
                    }
                case let .failure(error):
                    os_log("%{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
                }
            }
        }
    }
}

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
                Text(notification.message)
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

#Preview {
    Group {
        NotificationsView(notifications: [OpenHABNotification(message: "message1", created: Date.now, id: UUID().uuidString), OpenHABNotification(message: "message2", created: Date.now, id: UUID().uuidString)])

        NotificationRow(notification: OpenHABNotification(message: "message3", created: Date.now))
    }
}
