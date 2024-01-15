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

import OpenHABCore
import os.log

import WatchConnectivity
import WatchKit

class OpenHABWatchAppDelegate: NSObject {
    var session: WCSession
    let delegate: WCSessionDelegate

    override init() {
        delegate = AppMessageService.singleton
        session = .default
        session.delegate = delegate
        session.activate()
        super.init()
    }
}

extension OpenHABWatchAppDelegate: WKApplicationDelegate {
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                backgroundTask.setTaskCompletedWithSnapshot(false)
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Be sure to complete the connectivity task once you’re done.
                connectivityTask.setTaskCompletedWithSnapshot(false)
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                urlSessionTask.setTaskCompletedWithSnapshot(false)
            case let relevantShortcutTask as WKRelevantShortcutRefreshBackgroundTask:
                // Be sure to complete the relevant-shortcut task once you're done.
                relevantShortcutTask.setTaskCompletedWithSnapshot(false)
            case let intentDidRunTask as WKIntentDidRunRefreshBackgroundTask:
                // Be sure to complete the intent-did-run task once you're done.
                intentDidRunTask.setTaskCompletedWithSnapshot(false)
            default:
                // make sure to complete unhandled task types
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    func applicationDidFinishLaunching() {
//        // Kingfisher setup
//        ImageDownloader.default.authenticationChallengeResponder = self
//        KingfisherManager.shared.defaultOptions = [.requestModifier(OpenHABAccessTokenAdapter(appData: ObservableOpenHABDataObject.shared))]
    }
}

// MARK: - ClientCertificateManagerDelegate

extension OpenHABWatchAppDelegate: ClientCertificateManagerDelegate {
    // delegate should ask user for a decision on whether to import the client certificate into the keychain
    func askForClientCertificateImport(_ clientCertificateManager: ClientCertificateManager?) {}

    // delegate should ask user for the export password used to decode the PKCS#12
    func askForCertificatePassword(_ clientCertificateManager: ClientCertificateManager?) {}

    // delegate should alert the user that an error occured importing the certificate
    func alertClientCertificateError(_ clientCertificateManager: ClientCertificateManager?, errMsg: String) {}
}
