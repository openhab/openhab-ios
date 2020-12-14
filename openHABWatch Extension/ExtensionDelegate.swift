// Copyright (c) 2010-2020 Contributors to the openHAB project
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
import OpenHABCoreWatch
import os.log
import WatchConnectivity
import WatchKit

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    static var extensionDelegate: ExtensionDelegate!

    var appData: ObservableOpenHABDataObject

    var session: WCSession? {
        didSet {
            if let session = session {
                session.delegate = AppMessageService.singleton
                session.activate()
            }
        }
    }

    var viewModel: UserData?

    override init() {
        appData = ObservableOpenHABDataObject.shared
        super.init()
        ExtensionDelegate.extensionDelegate = self

        ImageDownloader.default.authenticationChallengeResponder = self
    }

    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
        activateWatchConnectivity()

        NetworkConnection.initialize(ignoreSSL: Preferences.ignoreSSL, adapter: OpenHABAccessTokenAdapter(appData: ExtensionDelegate.extensionDelegate.appData))

        NetworkConnection.shared.assignDelegates(serverDelegate: self, clientDelegate: self)

        KingfisherManager.shared.defaultOptions = [.requestModifier(OpenHABAccessTokenAdapter(appData: ExtensionDelegate.extensionDelegate.appData))]
    }

    func activateWatchConnectivity() {
        // WCSession.isSupported is always supported on a Watch
        session = WCSession.default
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        AppState.singleton.active = true
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
        AppState.singleton.active = false
    }

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
}

// MARK: Kingfisher authentication with NSURLCredential

extension ExtensionDelegate: AuthenticationChallengeResponsable {
    // sessionDelegate.onReceiveSessionTaskChallenge
    func downloader(_ downloader: ImageDownloader,
                    task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let (disposition, credential) = onReceiveSessionTaskChallenge(URLSession(configuration: .default), task, challenge)
        completionHandler(disposition, credential)
    }

    // sessionDelegate.onReceiveSessionChallenge
    func downloader(_ downloader: ImageDownloader,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let (disposition, credential) = onReceiveSessionChallenge(URLSession(configuration: .default), challenge)
        completionHandler(disposition, credential)
    }
}

// MARK: - ServerCertificateManagerDelegate

extension ExtensionDelegate: ServerCertificateManagerDelegate {
    // delegate should ask user for a decision on what to do with invalid certificate
    func evaluateServerTrust(_ policy: ServerCertificateManager?, summary certificateSummary: String?, forDomain domain: String?) {
        guard viewModel != nil else {
            policy!.evaluateResult = .deny
            return
        }
        DispatchQueue.main.async {
            self.viewModel?.showCertificateAlert = true
            self.viewModel?.certificateErrorDescription = String(format: NSLocalizedString("ssl_certificate_invalid", comment: ""), certificateSummary ?? "", domain ?? "")
        }
    }

    // certificate received from openHAB doesn't match our record, ask user for a decision
    func evaluateCertificateMismatch(_ policy: ServerCertificateManager?, summary certificateSummary: String?, forDomain domain: String?) {
        guard viewModel != nil else {
            policy!.evaluateResult = .deny
            return
        }
        DispatchQueue.main.async {
            self.viewModel?.showCertificateAlert = true
            self.viewModel?.certificateErrorDescription = String(format: NSLocalizedString("ssl_certificate_no_match", comment: ""), certificateSummary ?? "", domain ?? "")
        }
    }

    func acceptedServerCertificatesChanged(_ policy: ServerCertificateManager?) {}
}

// MARK: - ClientCertificateManagerDelegate

extension ExtensionDelegate: ClientCertificateManagerDelegate {
    // delegate should ask user for a decision on whether to import the client certificate into the keychain
    func askForClientCertificateImport(_ clientCertificateManager: ClientCertificateManager?) {}

    // delegate should ask user for the export password used to decode the PKCS#12
    func askForCertificatePassword(_ clientCertificateManager: ClientCertificateManager?) {}

    // delegate should alert the user that an error occured importing the certificate
    func alertClientCertificateError(_ clientCertificateManager: ClientCertificateManager?, errMsg: String) {}
}
