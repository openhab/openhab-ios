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

import Alamofire
import os.log

// https://medium.com/@AladinWay/write-a-networking-layer-in-swift-4-using-alamofire-5-and-codable-part-2-perform-request-and-b5c7ee2e012d
// Transition from AFNetworking to Alamofire 5.0
// SessionManager --> Session
// serverTrustPolicyManager --> serverTrustManager
// ServerTrustPolicyManager --> ServerTrustManager
public let onReceiveSessionTaskChallenge = { (_: URLSession, _: URLSessionTask, challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) in

    var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
    var credential: URLCredential?

    if challenge.previousFailureCount > 0 {
        return (.cancelAuthenticationChallenge, credential)
    } else if challenge.protectionSpace.authenticationMethod.isAny(of: NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodDefault) {
        let localUrl = URL(string: Preferences.localUrl)
        let remoteUrl = URL(string: Preferences.remoteUrl)
        if challenge.protectionSpace.host == localUrl?.host || challenge.protectionSpace.host == remoteUrl?.host {
            credential = URLCredential(user: Preferences.username, password: Preferences.password, persistence: .forSession)
            disposition = .useCredential
            os_log("HTTP BasicAuth host:'%{PUBLIC}@'", log: .default, type: .error, challenge.protectionSpace.host)
        }
    }
    return (disposition, credential)
}

public let onReceiveSessionChallenge = { (_: URLSession, challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) in

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

public protocol CommItem {
    var link: String { get set }
}

public class NetworkConnection {
    public static var shared: NetworkConnection!

    public static var atmosphereTrackingId = ""

    public var clientCertificateManager = ClientCertificateManager()
    public var serverCertificateManager: ServerCertificateManager!
    public var manager: Alamofire.SessionManager!
    public var rootUrl: URL?

    init(ignoreSSL: Bool,
         manager: SessionManager = SessionManager(
             configuration: URLSessionConfiguration.default,
             delegate: SessionDelegate()
         ),
         adapter: RequestAdapter?) {
        serverCertificateManager = ServerCertificateManager(ignoreSSL: ignoreSSL)
        serverCertificateManager.initializeCertificatesStore()
        self.manager = manager
        self.manager.startRequestsImmediately = false
        self.manager.delegate.sessionDidReceiveChallenge = onReceiveSessionChallenge
        self.manager.delegate.taskDidReceiveChallenge = onReceiveSessionTaskChallenge
        self.manager.adapter = adapter
    }

    public class func initialize(ignoreSSL: Bool, adapter: RequestAdapter?) {
        shared = NetworkConnection(ignoreSSL: ignoreSSL, adapter: adapter)
    }

    public static func register(prefsURL: String,
                                deviceToken: String,
                                deviceId: String,
                                deviceName: String, completionHandler: @escaping (DataResponse<Data>) -> Void) {
        if let url = Endpoint.appleRegistration(prefsURL: prefsURL, deviceToken: deviceToken, deviceId: deviceId, deviceName: deviceName).url {
            load(from: url, completionHandler: completionHandler)
        }
    }

    public static func sitemaps(openHABRootUrl: String,
                                completionHandler: @escaping (DataResponse<Data>) -> Void) {
        if let url = Endpoint.sitemaps(openHABRootUrl: openHABRootUrl).url {
            load(from: url, completionHandler: completionHandler)
        }
    }

    public static func tracker(openHABRootUrl: String,
                               completionHandler: @escaping (DataResponse<Data>) -> Void) {
        if let url = Endpoint.tracker(openHABRootUrl: openHABRootUrl).url {
            load(from: url, completionHandler: completionHandler)
        }
    }

    public static func notification(urlString: String,
                                    completionHandler: @escaping (DataResponse<Data>) -> Void) {
        if let notificationsUrl = Endpoint.notification(prefsURL: urlString).url {
            load(from: notificationsUrl, completionHandler: completionHandler)
        }
    }

    public static func sendCommand(item: CommItem, commandToSend command: String?) -> DataRequest? {
        if let commandUrl = URL(string: item.link) {
            var commandRequest = URLRequest(url: commandUrl)

            commandRequest.httpMethod = "POST"
            commandRequest.httpBody = command?.data(using: .utf8)
            commandRequest.setValue("text/plain", forHTTPHeaderField: "Content-type")

            os_log("Timeout %{PUBLIC}g", log: .default, type: .info, commandRequest.timeoutInterval)
            let link = item.link
            os_log("OpenHABViewController posting %{PUBLIC}@ command to %{PUBLIC}@", log: .default, type: .info, command ?? "", link)
            os_log("%{PUBLIC}@", log: .default, type: .info, commandRequest.debugDescription)

            return NetworkConnection.shared.manager.request(commandRequest)
                .validate(statusCode: 200 ..< 300)
                .responseData { response in
                    switch response.result {
                    case .success:
                        os_log("Command sent!", log: .remoteAccess, type: .info)
                    case let .failure(error):
                        os_log("%{PUBLIC}@ %d", log: .default, type: .error, error.localizedDescription, response.response?.statusCode ?? 0)
                    }
                }
        }
        return nil
    }

    public static func page(url: URL?,
                            longPolling: Bool,
                            openHABVersion: Int,
                            completionHandler: @escaping (DataResponse<Data>) -> Void) -> DataRequest? {
        guard let url = url else { return nil }

        var pageRequest = URLRequest(url: url)

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
            pageRequest.timeoutInterval = 10.0
        }
        pageRequest.setValue(atmosphereTrackingId, forHTTPHeaderField: "X-Atmosphere-tracking-id")

        os_log("OpenHABViewController sending new request", log: .remoteAccess, type: .error)

        return NetworkConnection.shared.manager.request(pageRequest)
            .validate(statusCode: 200 ..< 300)
            .responseData(completionHandler: completionHandler)
    }

    public static func page(pageUrl: String,
                            longPolling: Bool,
                            openHABVersion: Int,
                            completionHandler: @escaping (DataResponse<Data>) -> Void) -> DataRequest? {
        if pageUrl == "" {
            return nil
        }
        os_log("pageUrl = %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, pageUrl)

        guard let pageToLoadUrl = URL(string: pageUrl) else { return nil }

        return page(url: pageToLoadUrl, longPolling: longPolling, openHABVersion: openHABVersion, completionHandler: completionHandler)
    }

    static func load(from url: URL, completionHandler: @escaping (DataResponse<Data>) -> Void) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0

        os_log("Firing request", log: .viewCycle, type: .debug)
        let task = NetworkConnection.shared.manager.request(request)
            .validate(statusCode: 200 ..< 300)
            .responseData(completionHandler: completionHandler)
        task.resume()
    }

    public func assignDelegates(serverDelegate: ServerCertificateManagerDelegate?, clientDelegate: ClientCertificateManagerDelegate) {
        serverCertificateManager.delegate = serverDelegate
        clientCertificateManager.delegate = clientDelegate
    }
}
