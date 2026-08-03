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
import SwiftUI

@main
struct OpenHABApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            OpenHABRootView()
                .onOpenURL { url in
                    if url.isFileURL {
                        let clientCertificateManager = CertificateManagers.clientCertificateManager
                        Task { @MainActor in
                            await clientCertificateManager.startImportClientCertificate(url: url)
                        }
                        return
                    }
                    // Strip the "openhab:" scheme prefix to recover the action string,
                    // preserving any colons inside the payload (e.g. "command:item:value").
                    let action = url.absoluteString.split(separator: ":").dropFirst().joined(separator: ":")
                    appDelegate.notificationDelegate.notifyNotificationListeners(action: action)
                }
        }
    }
}
