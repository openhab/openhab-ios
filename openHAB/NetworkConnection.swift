//
//  NetworkConnection.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 10/08/19.
//  Copyright (c) 2019 David O'Neill. All rights reserved.

import Alamofire
import os.log

// https://medium.com/@AladinWay/write-a-networking-layer-in-swift-4-using-alamofire-5-and-codable-part-2-perform-request-and-b5c7ee2e012d
// Transition from AFNetworking to Alamofire 5.0
// SessionManager --> Session
// serverTrustPolicyManager --> serverTrustManager
// ServerTrustPolicyManager --> ServerTrustManager
let onReceiveSessionTaskChallenge = { (session: URLSession, task: URLSessionTask, challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) in

    var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
    var credential: URLCredential?

    if challenge.previousFailureCount > 0 {
        return (.cancelAuthenticationChallenge, credential)
    } else if challenge.protectionSpace.authenticationMethod.isAny(of: NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodDefault) {
        if challenge.protectionSpace.host == NetworkConnection.shared.rootUrl?.host {
            credential = URLCredential(user: Preferences.username, password: Preferences.password, persistence: .forSession)
            disposition = .useCredential
            os_log("HTTP BasicAuth host:'%{PUBLIC}@'", log: .default, type: .error, challenge.protectionSpace.host)
        }
    }
    return (disposition, credential)
}

let onReceiveSessionChallenge = { (session: URLSession, challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) in

    var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
    var credential: URLCredential?

    switch challenge.protectionSpace.authenticationMethod {
    case NSURLAuthenticationMethodServerTrust:
        return NetworkConnection.shared.serverCertificateManager.evaluateTrust(challenge: challenge)
    case NSURLAuthenticationMethodClientCertificate:
        return NetworkConnection.shared.clientCertificateManager.evaluateTrust(challenge: challenge)
    default:
        if challenge.previousFailureCount > 0 {
            disposition = .cancelAuthenticationChallenge
        } else {
            credential = NetworkConnection.shared.manager.session.configuration.urlCredentialStorage?.defaultCredential(for: challenge.protectionSpace)
            if credential != nil {
                disposition = .useCredential
            }
        }
        return (disposition, credential)
    }
}

class NetworkConnection {

    static var shared: NetworkConnection!

    static var atmosphereTrackingId = ""

    var clientCertificateManager = ClientCertificateManager()
    var serverCertificateManager: ServerCertificateManager!
    var manager: Alamofire.SessionManager!
    var rootUrl: URL?

    init(ignoreSSL: Bool,
         manager: SessionManager = SessionManager(configuration: URLSessionConfiguration.default,
                                                  delegate: SessionDelegate() ),
         adapter: RequestAdapter?
        ) {
        serverCertificateManager = ServerCertificateManager(ignoreCertificates: ignoreSSL)
        serverCertificateManager.initializeCertificatesStore()
        self.manager = manager
        self.manager.startRequestsImmediately = false
        self.manager.delegate.sessionDidReceiveChallenge = onReceiveSessionChallenge
        self.manager.delegate.taskDidReceiveChallenge = onReceiveSessionTaskChallenge
        self.manager.adapter = adapter
    }

    class func initialize(ignoreSSL: Bool, adapter: RequestAdapter?) {
        shared = NetworkConnection(ignoreSSL: ignoreSSL, adapter: adapter)
    }

    static func register(prefsURL: String,
                         deviceToken: String,
                         deviceId: String,
                         deviceName: String, completionHandler: @escaping (DataResponse<Data>) -> Void) {

        if let registrationUrl = Endpoint.appleRegistration(prefsURL: prefsURL, deviceToken: deviceToken, deviceId: deviceId, deviceName: deviceName).url {
            let registrationRequest = URLRequest(url: registrationUrl)

            os_log("Registration URL = %{PUBLIC}@", log: .notifications, type: .info, registrationUrl.absoluteString)
            let task = NetworkConnection.shared.manager.request(registrationRequest)
                .validate(statusCode: 200..<300)
                .responseData(completionHandler: completionHandler)
            task.resume()
        }
    }

    static func sitemaps(openHABRootUrl: String,
                         completionHandler: @escaping (DataResponse<Data>) -> Void) {

        if let sitemapsUrl = Endpoint.sitemaps(openHABRootUrl: openHABRootUrl).url {
            var sitemapsRequest = URLRequest(url: sitemapsUrl)
            sitemapsRequest.timeoutInterval = 10.0

            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            os_log("Firing request", log: .viewCycle, type: .info)

            let task = NetworkConnection.shared.manager.request(sitemapsRequest)
                .validate(statusCode: 200..<300)
                .responseData(completionHandler: completionHandler)
            task.resume()
        }
    }

    static func tracker(openHABRootUrl: String,
                        completionHandler: @escaping (DataResponse<Data>) -> Void) {
        if let pageToLoadUrl = Endpoint.tracker(openHABRootUrl: openHABRootUrl).url {
            var pageRequest = URLRequest(url: pageToLoadUrl)

            pageRequest.timeoutInterval = 10.0
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = true
            }

            let task = NetworkConnection.shared.manager.request(pageRequest)
                .validate(statusCode: 200..<300)
                .responseData(completionHandler: completionHandler)
            task.resume()
        }
    }

    static func sendCommand(item: OpenHABItem, commandToSend command: String?) -> DataRequest? {

        if let commandUrl = URL(string: item.link) {
            var commandRequest = URLRequest(url: commandUrl)

            commandRequest.httpMethod = "POST"
            commandRequest.httpBody = command?.data(using: .utf8)
            commandRequest.setValue("text/plain", forHTTPHeaderField: "Content-type")

            os_log("Timeout %{PUBLIC}g", log: .default, type: .info, commandRequest.timeoutInterval)
            let link = item.link
            os_log("OpenHABViewController posting %{PUBLIC}@ command to %{PUBLIC}@", log: .default, type: .info, command  ?? "", link)
            os_log("%{PUBLIC}@", log: .default, type: .info, commandRequest.debugDescription)

            return NetworkConnection.shared.manager.request(commandRequest)
                .validate(statusCode: 200..<300)
                .responseData { (response) in
                    switch response.result {
                    case .success:
                        os_log("Command sent!", log: .remoteAccess, type: .info)
                    case .failure(let error):
                        os_log("%{PUBLIC}@ %d", log: .default, type: .error, error.localizedDescription, response.response?.statusCode ?? 0)
                    }
                }
        }
        return nil
    }

    static func page(pageUrl: String,
                     longPolling: Bool,
                     openHABVersion: Int,
                     completionHandler: @escaping (DataResponse<Data>) -> Void) -> DataRequest? {

        if pageUrl == "" {
        return nil
        }
        os_log("pageUrl = %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, pageUrl)

        guard let pageToLoadUrl = URL(string: pageUrl) else { return nil }
        var pageRequest = URLRequest(url: pageToLoadUrl)

        // We accept XML only if openHAB is 1.X
        if openHABVersion == 1 {
            pageRequest.setValue("application/xml", forHTTPHeaderField: "Accept")
        }

        pageRequest.setValue("1.0", forHTTPHeaderField: "X-Atmosphere-Framework")
        if longPolling {
            os_log("long polling, so setting atmosphere transport", log: OSLog.remoteAccess, type: .info)
            pageRequest.setValue("long-polling", forHTTPHeaderField: "X-Atmosphere-Transport")
            pageRequest.timeoutInterval = 300.0
        } else {
            atmosphereTrackingId = "0"
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            pageRequest.timeoutInterval = 10.0
        }
        pageRequest.setValue(atmosphereTrackingId, forHTTPHeaderField: "X-Atmosphere-tracking-id")

        os_log("OpenHABViewController sending new request", log: .remoteAccess, type: .error)

        return NetworkConnection.shared.manager.request(pageRequest)
        .validate(statusCode: 200..<300)
            .responseData (completionHandler: completionHandler)

    }

    static func notification (prefsURL: String,
                              completionHandler: @escaping (DataResponse<Data>) -> Void) {
        if let notificationsUrl = Endpoint.notification(prefsURL: Preferences.remoteUrl).url {
            let notificationsRequest = URLRequest(url: notificationsUrl)

            let task = NetworkConnection.shared.manager.request(notificationsRequest)
                .validate(statusCode: 200..<300)
                .responseData (completionHandler: completionHandler)
            task.resume()
        }
    }

    func assignDelegates(serverDelegate: ServerCertificateManagerDelegate?, clientDelegate: ClientCertificateManagerDelegate) {
        serverCertificateManager.delegate = serverDelegate
        clientCertificateManager.delegate = clientDelegate
    }

    func setRootUrl(_ url: String?) {
        self.rootUrl = URL(string: url ?? "")
    }
}
