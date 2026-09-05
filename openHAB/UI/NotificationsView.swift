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
    var notification: OpenHABNotification
    var connection: ConnectionInfo
    var onAction: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // iOS notification-style header: small icon + source name + relative time
            HStack(spacing: 6) {
                if notification.isHideNotification {
                    Image(systemName: "bell.slash")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.secondary)
                } else {
                    KFImage(iconUrl)
                        .withOpenHABCredentials(for: connection)
                        .placeholder { Image("openHABIcon").resizable() }
                        .resizable()
                        .frame(width: 18, height: 18)
                        .clipShape(.rect(cornerRadius: 4))
                }
                Text("openHAB")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let timeStamp = notification.created {
                    Text(timeStamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if notification.isHideNotification {
                Text(String(localized: "notification_hide_type", comment: ""))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(notification.title.isEmpty ? String(localized: "message_not_decoded", comment: "") : notification.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let subtitle = notification.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            if let tag = notification.payload?.tag, !tag.isEmpty {
                Text(tag)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            if let action = notification.onClickAction {
                onAction(action)
            }
        }
        .contextMenu {
            if let onClickAction = notification.onClickAction {
                Button {
                    onAction(onClickAction)
                } label: {
                    Label("notification_action_open", systemImage: "arrow.up.right")
                }
            }
            if notification.onClickAction != nil, !notification.actions.isEmpty {
                Divider()
            }
            ForEach(notification.actions, id: \.action) { item in
                Button(item.title) { onAction(item.action) }
            }
        }
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
                    message: "Motion detected at front door",
                    icon: "motion",
                    onClickAction: "ui:/overview",
                    actions: [
                        NotificationActionItem(title: "View Camera", action: "ui:/camera"),
                        NotificationActionItem(title: "Turn on Light", action: "sendCommand:FrontLight:ON")
                    ],
                    created: .now.addingTimeInterval(-90),
                    v: 0
                ),
                OpenHABNotification(
                    id: UUID().uuidString,
                    message: "Preview Notification 1",
                    icon: "sun",
                    onClickAction: "ui:/overview",
                    actions: [NotificationActionItem(title: "Open", action: "ui:/overview")],
                    created: .now,
                    v: 0
                ),
                OpenHABNotification(
                    id: UUID().uuidString,
                    message: "Preview Notification 2",
                    icon: "moon",
                    created: .now.addingTimeInterval(-3600),
                    v: 0
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

struct NotificationsView<Tracker: NetworkTracking>: View where Tracker: ObservableObject {
    @ObservedObject var networkTracker: Tracker
    @State var notifications: [OpenHABNotification] = []
    let loadNotifications: NotificationLoader
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(notifications, id: \.id) { notification in
            if let connection = networkTracker.activeConnection {
                NotificationRow(notification: notification, connection: connection) { action in
                    executeAction(action, cloudUserId: notification.cloudUserId)
                    dismiss()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .listStyle(.plain)
        .overlay {
            if notifications.isEmpty {
                ContentUnavailableView("No Notifications", systemImage: "bell.slash")
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
        .onReceive(NotificationCenter.default.publisher(for: .openHABDidReceiveNotification)) { _ in
            Task {
                notifications = await loadNotifications()
            }
        }
    }

    private func executeAction(_ action: String, cloudUserId: String?) {
        NotificationCenter.default.post(
            name: .openHABHandleNotificationAction,
            object: nil,
            userInfo: ["action": action, "cloudUserId": cloudUserId as Any]
        )
    }
}

extension NotificationsView where Tracker == MainActorNetworkTracker {
    init(notifications: [OpenHABNotification] = []) {
        #if DEBUG
        if ProcessInfo.processInfo.environment["UITestNotifications"] != nil {
            networkTracker = MainActorNetworkTracker.shared
            _notifications = State(initialValue: [])
            loadNotifications = {
                [
                    OpenHABNotification(
                        id: "uitest-1",
                        message: "UITest Front Door Alert",
                        onClickAction: "ui:/overview",
                        actions: [NotificationActionItem(title: "Open Camera", action: "ui:/overview")],
                        v: 0
                    ),
                    OpenHABNotification(id: "uitest-2", message: "UITest Regular Info", v: 0)
                ]
            }
            return
        }
        #endif
        networkTracker = MainActorNetworkTracker.shared
        _notifications = State(initialValue: notifications)
        loadNotifications = {
            do {
                guard let config = await Preferences.shared.getNotificationConnection() else {
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
