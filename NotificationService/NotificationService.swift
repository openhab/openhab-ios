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

import Foundation
import OpenHABCore
import os.log
import UniformTypeIdentifiers
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        if let bestAttemptContent {
            var notificationActions: [UNNotificationAction] = []
            let userInfo = bestAttemptContent.userInfo

            os_log("didReceive userInfo %{PUBLIC}@", log: .default, type: .info, userInfo)

            if let title = userInfo["title"] as? String {
                bestAttemptContent.title = title
            }
            if let message = userInfo["message"] as? String {
                bestAttemptContent.body = message
            }

            // Check if the user has defined custom actions in the payload
            if let actionsArray = parseActions(userInfo), let category = parseCategory(userInfo) {
                for actionDict in actionsArray {
                    if let action = actionDict["action"],
                       let title = actionDict["title"] {
                        var options: UNNotificationActionOptions = []
                        // navigate/browser options need to bring the app to the foreground
                        if action.hasPrefix("ui") || action.hasPrefix("http") {
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
                        // Check if the new category already exists, this is a hash of the actions string done by the cloud service
                        let existingCategoryIdentifiers = existingCategories.map(\.identifier)
                        if !existingCategoryIdentifiers.contains(category) {
                            var updatedCategories = existingCategories
                            os_log("handleNotification adding category %{PUBLIC}@", log: .default, type: .info, category)
                            updatedCategories.insert(notificationCategory)
                            UNUserNotificationCenter.current().setNotificationCategories(updatedCategories)
                        }
                    }
                }
            }

            // check if there is an attachment to put on the notification
            // this should be last as we need to wait for media
            // TODO: we should support relative paths and try the user's openHAB (local,remote) for content
            if let attachmentURLString = userInfo["media-attachment-url"] as? String, let attachmentURL = URL(string: attachmentURLString) {
                if let scheme = attachmentURL.scheme {
                    let isItem = scheme == "item"
                    let downloadHandler: (URL, @escaping (UNNotificationAttachment?) -> Void) -> Void = if isItem {
                        downloadAndAttachItemImage
                    } else {
                        downloadAndAttachMedia
                    }
                    os_log("handleNotification downloading %{PUBLIC}@", log: .default, type: .info, attachmentURLString)
                    downloadHandler(attachmentURL) { attachment in
                        if let attachment {
                            os_log("handleNotification attaching %{PUBLIC}@", log: .default, type: .info, attachmentURLString)
                            bestAttemptContent.attachments = [attachment]
                        } else {
                            os_log("handleNotification could not attach %{PUBLIC}@", log: .default, type: .info, attachmentURLString)
                        }
                        contentHandler(bestAttemptContent)
                    }
                } else {
                    contentHandler(bestAttemptContent)
                }
            } else {
                contentHandler(bestAttemptContent)
            }
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

    private func downloadAndAttachMedia(url: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            guard let localURL else {
                os_log("Error downloading media %{PUBLIC}@", log: .default, type: .error, error?.localizedDescription ?? "Unknown error")
                completion(nil)
                return
            }
            self.attachFile(localURL: localURL, mimeType: response?.mimeType, completion: completion)
        }
        task.resume()
    }

    func downloadAndAttachItemImage(attachmentURL: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
        guard let scheme = attachmentURL.scheme else {
            os_log("Could not find scheme %{PUBLIC}@", log: .default, type: .info)
            completion(nil)
            return
        }

        let itemName = String(attachmentURL.absoluteString.dropFirst(scheme.count + 1))

        let client = HTTPClient(username: Preferences.username, password: Preferences.username)
        client.getItem(baseURLs: [Preferences.localUrl, Preferences.remoteUrl], itemName: itemName) { item, error in
            guard let item else {
                os_log("Could not find item %{PUBLIC}@", log: .default, type: .info, itemName)
                completion(nil)
                return
            }
            if let state = item.state {
                do {
                    // Extract MIME type and base64 string
                    let pattern = "^data:(.*?);base64,(.*)$"
                    let regex = try NSRegularExpression(pattern: pattern, options: [])
                    if let match = regex.firstMatch(in: state, options: [], range: NSRange(location: 0, length: state.utf16.count)) {
                        let mimeTypeRange = Range(match.range(at: 1), in: state)
                        let base64Range = Range(match.range(at: 2), in: state)
                        if let mimeTypeRange, let base64Range {
                            let mimeType = String(state[mimeTypeRange])
                            let base64String = String(state[base64Range])
                            if let imageData = Data(base64Encoded: base64String) {
                                // Create a temporary file URL
                                let tempDirectory = FileManager.default.temporaryDirectory
                                let tempFileURL = tempDirectory.appendingPathComponent(UUID().uuidString)
                                do {
                                    try imageData.write(to: tempFileURL)
                                    os_log("Image saved to temporary file: %{PUBLIC}@", log: .default, type: .info, tempFileURL.absoluteString)
                                    self.attachFile(localURL: tempFileURL, mimeType: mimeType, completion: completion)
                                    return
                                } catch {
                                    os_log("Failed to write image data to file: %{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
                                }
                            } else {
                                os_log("Failed to decode base64 string to Data", log: .default, type: .error)
                            }
                        }
                    }
                } catch {
                    os_log("Failed to parse data: %{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
                }
            }
            completion(nil)
        }
    }

    func attachFile(localURL: URL, mimeType: String?, completion: @escaping (UNNotificationAttachment?) -> Void) {
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
            completion(attachment)
            return
        } catch {
            os_log("Failed to create UNNotificationAttachment: %{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
        }
        completion(nil)
    }
}
