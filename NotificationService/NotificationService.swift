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

import Combine
import Foundation
import OpenHABCore
import os.log
import UniformTypeIdentifiers
@preconcurrency import UserNotifications

enum NotificationServiceError: Error {
    case unknown
    case noScheme(String?)
    case failedToParse
    case failedToDecode
    case handleNotificationCouldNotAttach
    case noActiveConnection

    var localizedDescription: String {
        switch self {
        case .unknown:
            "Unknown error"
        case let .noScheme(searched):
            "Could not find scheme \(searched ?? "<none>")"
        case .failedToParse:
            "Failed to parse JSON"
        case .failedToDecode:
            "Failed to decode base64 string to Data"
        case .handleNotificationCouldNotAttach:
            "HandleNotification could not attach"
        case .noActiveConnection:
            "No active connection"
        }
    }
}

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    var cancellables = Set<AnyCancellable>()
    var networkTracker: NetworkTracker?
    var cloudUserId: String?
    let logger = Logger(subsystem: "org.openhab.network", category: "NotificationService")

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        guard let bestAttemptContent else { return }

        var notificationActions: [UNNotificationAction] = []
        let userInfo = bestAttemptContent.userInfo

        logger.info("didReceive userInfo \(userInfo)")

        if let title = userInfo["title"] as? String {
            bestAttemptContent.title = title
        }
        if let message = userInfo["message"] as? String {
            bestAttemptContent.body = message
        }

        cloudUserId = userInfo["userId"] as? String

        // Check if the user has defined custom actions in the payload
        if let actionsArray = parseActions(userInfo), let category = parseCategory(userInfo) {
            for actionDict in actionsArray {
                if let action = actionDict["action"],
                   let title = actionDict["title"] {
                    var options: UNNotificationActionOptions = []
                    // navigate/browser options need to bring the app to the foreground
                    if action.hasPrefix("ui") || action.hasPrefix("http") || action.hasPrefix("app") {
                        options = [.foreground]
                    }
                    let notificationAction = UNNotificationAction(
                        identifier: action,
                        title: title,
                        options: options
                    )
                    notificationActions.append(notificationAction)
                }
            }
            if !notificationActions.isEmpty {
                os_log("didReceive registering %{PUBLIC}@ for category %{PUBLIC}@", log: .default, type: .info, notificationActions, category)
                let notificationCategory =
                    UNNotificationCategory(
                        identifier: category,
                        actions: notificationActions,
                        intentIdentifiers: [],
                        options: .customDismissAction
                    )
                UNUserNotificationCenter.current().getNotificationCategories { existingCategories in
                    var updatedCategories = existingCategories
                    os_log("handleNotification adding category %{PUBLIC}@", log: .default, type: .info, category)
                    updatedCategories.insert(notificationCategory)
                    UNUserNotificationCenter.current().setNotificationCategories(updatedCategories)
                }
            }
        }

        // check if there is an attachment to put on the notification
        // this should be last as we need to wait for media
        // TODO: we should support relative paths and try the user's openHAB (local,remote) for content
        if let attachmentURLString = userInfo["media-attachment-url"] as? String {
            // HERE we switch to async usage
            Task {
                do {
                    let unNotificationAttachment = if attachmentURLString.starts(with: "item:") {
                        try await downloadAndAttachItemImage(itemURI: attachmentURLString)
                    } else {
                        try await downloadAndAttachMedia(url: attachmentURLString)
                    }
                    if let unNotificationAttachment {
                        bestAttemptContent.attachments = [unNotificationAttachment]
                    } else {
                        throw NotificationServiceError.handleNotificationCouldNotAttach
                    }
                } catch {
                    os_log("Error fetching data: %{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
                }
                contentHandler(bestAttemptContent)
            }

        } else {
            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        os_log("serviceExtensionTimeWillExpire", log: .default, type: .info)
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    private func parseActions(_ userInfo: [AnyHashable: Any]) -> [[String: String]]? {
        // Extract actions and convert it from JSON string to an array of dictionaries
        if let actionsString = userInfo["actions"] as? String, let actionsData = actionsString.data(using: .utf8) {
            do {
                if let actionsArray = try JSONSerialization.jsonObject(with: actionsData, options: []) as? [[String: String]] {
                    return actionsArray
                }
            } catch {
                os_log("Error parsing actions: %{PUBLIC}@", log: .default, type: .info, error.localizedDescription)
            }
        }
        return nil
    }

    private func parseCategory(_ userInfo: [AnyHashable: Any]) -> String? {
        // Extract category from aps dictionary
        if let aps = userInfo["aps"] as? [String: Any],
           let category = aps["category"] as? String {
            return category
        }
        return nil
    }

    private func downloadForAttachment(attachmentURLString: String) -> (URL?, String?) {
        var returnValues: (URL?, String?)
        Task {
            do {
                returnValues = if attachmentURLString.starts(with: "item:") {
                    try await downloadItemImage(itemURI: attachmentURLString)
                } else {
                    try await downloadMedia(url: attachmentURLString)
                }

            } catch {
                os_log("Error fetching data: %{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
            }
        }
        return returnValues
    }

    private func downloadAndAttachMedia(url: String) async throws -> UNNotificationAttachment? {
        let (localURL, mimeType) = try await downloadMedia(url: url)
        guard let localURL else { return nil }
        return await attachFile(localURL: localURL, mimeType: mimeType)
    }

    private func downloadMedia(url: String) async throws -> (URL?, String?) {
        guard let fullURL = await resolveFullURL(from: url) else { return (nil, nil) }

        guard let activeConfig = await networkTracker().waitForActiveConnection()?.configuration else { return (nil, nil) }

        let client = HTTPClient(configuration: activeConfig)

        let (localURL, urlResponse) = try await client.downloadFile(url: fullURL)
        return (localURL, urlResponse.mimeType)
    }

    // 🔹 Extracted helper function to determine full URL
    private func resolveFullURL(from url: String) async -> URL? {
        if url.starts(with: "/") {
            guard let activeConfig = await networkTracker().waitForActiveConnection()?.configuration else { return nil }
            return URL(string: activeConfig.url)?.appendingPathComponent(url)
        } else {
            return URL(string: url)
        }
    }

    func downloadAndAttachItemImage(itemURI: String) async throws -> UNNotificationAttachment? {
        let (tempFileURL, mimeType) = try await downloadItemImage(itemURI: itemURI)
        guard let tempFileURL else { return nil }
        return await attachFile(localURL: tempFileURL, mimeType: mimeType)
    }

    func downloadItemImage(itemURI: String) async throws -> (URL?, String?) {
        guard let itemURL = URL(string: itemURI), let scheme = itemURL.scheme else {
            throw NotificationServiceError.noScheme(itemURI)
        }

        let itemName = String(itemURL.absoluteString.dropFirst(scheme.count + 1))

        let item = try await networkTracker().getItemByName(id: itemName)
        guard let state = item?.state else { return (nil, nil) }

        // Extract MIME type and base64 string
        let pattern = /^data:(.*?);base64,(.*)$/
        guard let firstMatch = state.firstMatch(of: pattern) else {
            throw NotificationServiceError.failedToParse
        }

        let mimeType = String(firstMatch.1)
        let base64String = String(firstMatch.2)
        guard let imageData = Data(base64Encoded: base64String) else {
            throw NotificationServiceError.failedToDecode
        }

        // Create a temporary file URL
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent(UUID().uuidString)
        try imageData.write(to: tempFileURL)

        os_log("Image saved to temporary file: %{PUBLIC}@", log: .default, type: .info, tempFileURL.absoluteString)
        return (tempFileURL, mimeType)
    }

    func attachFile(localURL: URL, mimeType: String?) async -> UNNotificationAttachment? {
        do {
            let fileManager = FileManager.default
            let tempDirectory = NSTemporaryDirectory()
            let tempFile = URL(fileURLWithPath: tempDirectory).appendingPathComponent(UUID().uuidString)

            try fileManager.moveItem(at: localURL, to: tempFile)
            let attachment: UNNotificationAttachment?

            if let mimeType,
               let utType = UTType(mimeType: mimeType),
               utType.conforms(to: .data) {
                let newTempFile = tempFile.appendingPathExtension(utType.preferredFilenameExtension ?? "")
                try fileManager.moveItem(at: tempFile, to: newTempFile)
                attachment = try UNNotificationAttachment(identifier: UUID().uuidString, url: newTempFile, options: nil)
            } else {
                os_log("Unrecognized MIME type or file extension", log: .default, type: .error)
                attachment = nil
            }
            return attachment
        } catch {
            os_log("Failed to create UNNotificationAttachment: %{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
        }
        return nil
    }

    func networkTracker() async -> NetworkTracker {
        if let cached = networkTracker {
            return cached
        }
        let tracker = NetworkTracker.shared
        let connections: [ConnectionConfiguration]
        if let cloudUserId,
           let uuid = await Preferences.storedSettingsId(forCloudUserId: cloudUserId),
           let instance = await Preferences.preferenceInstance(for: uuid.uuidString) {
            logger.info("setting up network tracking for \(cloudUserId)")
            connections = [instance.localConnectionConfig, instance.remoteConnectionConfig]
        } else {
            logger.info("Using default connection configurations")
            connections = await [Preferences.localConnectionConfig, Preferences.remoteConnectionConfig]
        }
        await tracker.startTracking(connectionConfigurations: connections)
        networkTracker = tracker
        return tracker
    }
}
