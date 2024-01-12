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

// Copyright (c) 2010-2023 Contributors to the openHAB project
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
import SDWebImage
import WatchConnectivity
import WatchKit

// MARK: SDWebImageDownloaderOperation

class OpenHABImageDownloaderOperation: SDWebImageDownloaderOperation {
    override func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let (disposition, credential) = onReceiveSessionChallenge(with: challenge)
        completionHandler(disposition, credential)
    }

    override func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let (disposition, credential) = onReceiveSessionTaskChallenge(with: challenge)
        completionHandler(disposition, credential)
    }
}

class OpenHABWatchAppDelegate: NSObject {
    var session: WCSession
    let delegate: WCSessionDelegate
//    var viewModel: UserData?

    override init() {
        delegate = AppMessageService.singleton
        session = .default
        session.delegate = delegate
        session.activate()
        super.init()

//        let appData = ObservableOpenHABDataObject.shared

//        NetworkConnection.initialize(ignoreSSL: Preferences.ignoreSSL, interceptor: OpenHABAccessTokenAdapter(appData: appData))
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
        // TODO:
        ImageDownloader.default.authenticationChallengeResponder = self

//        NetworkConnection.shared.assignDelegates(serverDelegate: self, clientDelegate: self)

        let appData = ObservableOpenHABDataObject.shared
        KingfisherManager.shared.defaultOptions = [.requestModifier(OpenHABAccessTokenAdapter(appData: appData))]
    }
}

// MARK: Kingfisher authentication with NSURLCredential

extension OpenHABWatchAppDelegate: AuthenticationChallengeResponsible {
    // sessionDelegate.onReceiveSessionTaskChallenge
    func downloader(_ downloader: ImageDownloader,
                    task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let (disposition, credential) = onReceiveSessionTaskChallenge(with: challenge)
        completionHandler(disposition, credential)
    }

    // sessionDelegate.onReceiveSessionChallenge
    func downloader(_ downloader: ImageDownloader,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let (disposition, credential) = onReceiveSessionChallenge(with: challenge)
        completionHandler(disposition, credential)
    }
}

// MARK: - ServerCertificateManagerDelegate

// extension OpenHABWatchAppDelegate: ServerCertificateManagerDelegate {
//    // delegate should ask user for a decision on what to do with invalid certificate
//    func evaluateServerTrust(_ policy: ServerCertificateManager?, summary certificateSummary: String?, forDomain domain: String?) {
//        guard viewModel != nil else {
//            policy!.evaluateResult = .deny
//            return
//        }
//        DispatchQueue.main.async {
//            self.viewModel?.showCertificateAlert = true
//            self.viewModel?.certificateErrorDescription = String(format: NSLocalizedString("ssl_certificate_invalid", comment: ""), certificateSummary ?? "", domain ?? "")
//        }
//    }
//
//    // certificate received from openHAB doesn't match our record, ask user for a decision
//    func evaluateCertificateMismatch(_ policy: ServerCertificateManager?, summary certificateSummary: String?, forDomain domain: String?) {
//        guard viewModel != nil else {
//            policy!.evaluateResult = .deny
//            return
//        }
//        DispatchQueue.main.async {
//            self.viewModel?.showCertificateAlert = true
//            self.viewModel?.certificateErrorDescription = String(format: NSLocalizedString("ssl_certificate_no_match", comment: ""), certificateSummary ?? "", domain ?? "")
//        }
//    }
//
//    func acceptedServerCertificatesChanged(_ policy: ServerCertificateManager?) {}
// }

// MARK: - ClientCertificateManagerDelegate

extension OpenHABWatchAppDelegate: ClientCertificateManagerDelegate {
    // delegate should ask user for a decision on whether to import the client certificate into the keychain
    func askForClientCertificateImport(_ clientCertificateManager: ClientCertificateManager?) {}

    // delegate should ask user for the export password used to decode the PKCS#12
    func askForCertificatePassword(_ clientCertificateManager: ClientCertificateManager?) {}

    // delegate should alert the user that an error occured importing the certificate
    func alertClientCertificateError(_ clientCertificateManager: ClientCertificateManager?, errMsg: String) {}
}
