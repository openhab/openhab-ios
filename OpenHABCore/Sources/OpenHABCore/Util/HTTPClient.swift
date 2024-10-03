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
import os.log

public class HTTPClient: NSObject {
    // MARK: - Properties

    private var session: URLSession!
    private let username: String
    private let password: String
    private let alwaysSendBasicAuth: Bool

    public init(username: String, password: String, alwaysSendBasicAuth: Bool = false) {
        self.username = username
        self.password = password
        self.alwaysSendBasicAuth = alwaysSendBasicAuth
        super.init()

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 60

        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    /**
     Sends a GET request to a specified base URL for a specified path and returns the response data via a completion handler.

     - Parameters:
     - baseURL: The base URL to attempt the request from.
     - path: An optional path component to append to the base URL.
     - completion: A closure to be executed once the request is complete. The closure takes three parameters:
     - data: The data returned by the server. This will be `nil` if the request fails.
     - response: The URL response object providing response metadata, such as HTTP headers and status code.
     - error: An error object that indicates why the request failed, or `nil` if the request was successful.
     */
    public func doGet(baseURL: URL, path: String?, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        doRequest(baseURL: baseURL, path: path, method: "GET") { result, response, error in
            let data = result as? Data
            completion(data, response, error)
        }
    }

    /**
     Sends a POST request to a specified base URL for a specified path and returns the response data via a completion handler.

     - Parameters:
     - baseURL: The base URL to attempt the request from.
     - path: An optional path component to append to the base URL.
     - body: The string to include as the HTTP body of the request.
     - completion: A closure to be executed once the request is complete. The closure takes three parameters:
     - data: The data returned by the server. This will be `nil` if the request fails.
     - response: The URL response object providing response metadata, such as HTTP headers and status code.
     - error: An error object that indicates why the request failed, or `nil` if the request was successful.
     */
    public func doPost(baseURL: URL, path: String?, body: String, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        doRequest(baseURL: baseURL, path: path, method: "POST", body: body) { result, response, error in
            let data = result as? Data
            completion(data, response, error)
        }
    }

    /**
     Sends a PUT request to a specified base URL for a specified path and returns the response data via a completion handler.

     - Parameters:
     - baseURL: The base URL to attempt the request from.
     - path: An optional path component to append to the base URL.
     - body: The string to include as the HTTP body of the request.
     - completion: A closure to be executed once the request is complete. The closure takes three parameters:
     - data: The data returned by the server. This will be `nil` if the request fails.
     - response: The URL response object providing response metadata, such as HTTP headers and status code.
     - error: An error object that indicates why the request failed, or `nil` if the request was successful.
     */
    public func doPut(baseURL: URL, path: String?, body: String, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        doRequest(baseURL: baseURL, path: path, method: "PUT", body: body) { result, response, error in
            let data = result as? Data
            completion(data, response, error)
        }
    }

    /**
     Fetches a specific OpenHAB item from a specified base URL and returns the item via a completion handler.

     - Parameters:
     - baseURL: The base URL to attempt the request from.
     - itemName: The name of the OpenHAB item to fetch.
     - completion: A closure to be executed once the request is complete. The closure takes two parameters:
     - item: An `OpenHABItem` object returned by the server. This will be `nil` if the request fails.
     - error: An error object that indicates why the request failed, or `nil` if the request was successful.
     */
    public func getItem(baseURL: URL, itemName: String, completion: @escaping (OpenHABItem?, Error?) -> Void) {
        os_log("getItem from URL %{public}@ and item %{public}@", log: .networking, type: .info, baseURL.absoluteString, itemName)
        doGet(baseURL: baseURL, path: "/rest/items/\(itemName)") { data, _, error in
            if let error {
                completion(nil, error)
            } else {
                do {
                    if let data {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)
                        let item = try data.decoded(as: OpenHABItem.CodingData.self, using: decoder)
                        completion(item.openHABItem, nil)
                    } else {
                        completion(nil, NSError(domain: "HTTPClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data for item"]))
                    }
                } catch {
                    os_log("getItemsInternal ERROR: %{PUBLIC}@", log: .networking, type: .info, String(describing: error))
                    completion(nil, error)
                }
            }
        }
    }

    public func getServerProperties(baseURL: URL, completion: @escaping (OpenHABServerProperties?, Error?) -> Void) {
        os_log("getServerProperties from URL %{public}@", log: .networking, type: .info, baseURL.absoluteString)
        doGet(baseURL: baseURL, path: "/rest/") { data, _, error in
            if let error {
                completion(nil, error)
            } else {
                do {
                    if let data {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)
                        let properties = try data.decoded(as: OpenHABServerProperties.self, using: decoder)
                        completion(properties, nil)
                    } else {
                        completion(nil, NSError(domain: "HTTPClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data for properties"]))
                    }
                } catch {
                    os_log("getServerProperties ERROR: %{PUBLIC}@", log: .networking, type: .info, String(describing: error))
                    completion(nil, error)
                }
            }
        }
    }

    /**
     Initiates a download request to a specified base URL for a specified path and returns the file URL via a completion handler.

     - Parameters:
     - baseURL: The base URL to attempt the download from.
     - path: The optional  path component to append to the base URL.
     - completionHandler: A closure to be executed once the download is complete. The closure takes three parameters:
     - fileURL: The local URL where the downloaded file is stored. This will be `nil` if the download fails.
     - response: The URL response object providing response metadata, such as HTTP headers and status code.
     - error: An error object that indicates why the request failed, or `nil` if the request was successful.
     */
    public func downloadFile(url: URL, completionHandler: @escaping @Sendable (URL?, URLResponse?, (any Error)?) -> Void) {
        doRequest(baseURL: url, path: nil, method: "GET", download: true) { result, response, error in
            let fileURL = result as? URL
            completionHandler(fileURL, response, error)
        }
    }

    // MARK: - Basic Authentication

    private func basicAuthHeader() -> String {
        let authString = "\(username):\(password)"
        let authData = authString.data(using: .utf8)!
        return "Basic \(authData.base64EncodedString())"
    }

    private func doRequest(baseURL: URL, path: String?, method: String, body: String? = nil, download: Bool = false, completion: @escaping (Any?, URLResponse?, Error?) -> Void) {
        var url = baseURL
        if let path {
            url.appendPathComponent(path)
        }

        func sendRequest() {
            var request = URLRequest(url: url)
            request.httpMethod = method
            if let body {
                request.httpBody = body.data(using: .utf8)
                request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
            }
            performRequest(request: request, download: download) { result, response, error in
                if let error {
                    os_log("Error with URL %{public}@ : %{public}@", log: .networking, type: .error, url.absoluteString, error.localizedDescription)
                    completion(nil, response, error)
                } else if let response = response as? HTTPURLResponse {
                    if (400 ... 599).contains(response.statusCode) {
                        os_log("HTTP error from URL %{public}@ : %{public}d", log: .networking, type: .error, url.absoluteString, response.statusCode)
                        completion(nil, response, NSError(domain: "HTTPClient", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP error \(response.statusCode)"]))
                    } else {
                        os_log("Response from URL %{public}@ : %{public}d", log: .networking, type: .info, url.absoluteString, response.statusCode)
                        completion(result, response, nil)
                    }
                }
            }
        }
        sendRequest()
    }

    private func performRequest(request: URLRequest, download: Bool, completion: @escaping (Any?, URLResponse?, Error?) -> Void) {
        var request = request
        if alwaysSendBasicAuth {
            request.setValue(basicAuthHeader(), forHTTPHeaderField: "Authorization")
        }

        let task: URLSessionTask = if download {
            session.downloadTask(with: request) { url, response, error in
                completion(url, response, error)
            }
        } else {
            session.dataTask(with: request) { data, response, error in
                completion(data, response, error)
            }
        }
        task.resume()
    }

    @available(watchOS 8.0, *)
    @available(iOS 15.0, *)
    private func performRequest(request: URLRequest, download: Bool) async throws -> (Any?, URLResponse?) {
        var request = request
        if alwaysSendBasicAuth {
            request.setValue(basicAuthHeader(), forHTTPHeaderField: "Authorization")
        }
        if download {
            return try await session.download(for: request)
        } else {
            return try await session.data(for: request)
        }
    }
}

extension HTTPClient: URLSessionDelegate, URLSessionTaskDelegate {
    // MARK: - URLSessionDelegate for Client Certificates and Basic Auth

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await urlSessionInternal(session, task: nil, didReceive: challenge)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await urlSessionInternal(session, task: task, didReceive: challenge)
    }

    private func urlSessionInternal(_ session: URLSession, task: URLSessionTask?, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        os_log("URLAuthenticationChallenge: %{public}@", log: .networking, type: .info, challenge.protectionSpace.authenticationMethod)
        let authenticationMethod = challenge.protectionSpace.authenticationMethod
        switch authenticationMethod {
        case NSURLAuthenticationMethodServerTrust:
            return await handleServerTrust(challenge: challenge)
        case NSURLAuthenticationMethodDefault, NSURLAuthenticationMethodHTTPBasic:
            if let task {
                task.authAttemptCount += 1
                if task.authAttemptCount > 1 {
                    return (.cancelAuthenticationChallenge, nil)
                } else {
                    return await handleBasicAuth(challenge: challenge)
                }
            } else {
                return await handleBasicAuth(challenge: challenge)
            }
        case NSURLAuthenticationMethodClientCertificate:
            return await handleClientCertificateAuth(challenge: challenge)
        default:
            return (.performDefaultHandling, nil)
        }
    }

    private func handleServerTrust(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }
        let credential = URLCredential(trust: serverTrust)
        return (.useCredential, credential)
    }

    private func handleBasicAuth(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let credential = URLCredential(user: username, password: password, persistence: .forSession)
        return (.useCredential, credential)
    }

    private func handleClientCertificateAuth(challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let certificateManager = ClientCertificateManager()
        let (disposition, credential) = certificateManager.evaluateTrust(with: challenge)
        return (disposition, credential)
    }
}

extension URLSessionTask {
    private static var authAttemptCountKey: UInt8 = 0

    var authAttemptCount: Int {
        get {
            objc_getAssociatedObject(self, &URLSessionTask.authAttemptCountKey) as? Int ?? 0
        }
        set {
            objc_setAssociatedObject(self, &URLSessionTask.authAttemptCountKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
