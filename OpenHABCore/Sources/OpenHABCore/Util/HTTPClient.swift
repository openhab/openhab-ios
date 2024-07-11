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

public class HTTPClient: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
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
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60

        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    /**
     Sends a GET request to multiple base URLs for a specified path and returns the response data via a completion handler.

     This function attempts to send a GET request to the provided base URLs in the given order. If a request fails (due to network issues or HTTP error codes between 400 and 599), it will automatically attempt the next URL in the list until all URLs are exhausted or a successful response is received.

     - Parameters:
     - baseURLs: An array of base URL strings to attempt the request from. The function will try each URL in the order provided.
     - path: An optional path component to append to each base URL.
     - completion: A closure to be executed once the request is complete. The closure takes three parameters:
     - data: The data returned by the server. This will be `nil` if the request fails.
     - response: The URL response object providing response metadata, such as HTTP headers and status code.
     - error: An error object that indicates why the request failed, or `nil` if the request was successful.
     */
    public func doGet(baseURLs: [String], path: String?, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        doRequest(baseURLs: baseURLs, path: path, method: "GET") { result, response, error in
            let data = result as? Data
            completion(data, response, error)
        }
    }

    /**
     Sends a POST request to multiple base URLs for a specified path and returns the response data via a completion handler.

     This function attempts to send a POST request to the provided base URLs in the given order. If a request fails (due to network issues or HTTP error codes between 400 and 599), it will automatically attempt the next URL in the list until all URLs are exhausted or a successful response is received.

     - Parameters:
     - baseURLs: An array of base URL strings to attempt the request from. The function will try each URL in the order provided.
     - path: An optional path component to append to each base URL.
     - body: The string to include as the HTTP body of the request.
     - completion: A closure to be executed once the request is complete. The closure takes three parameters:
     - data: The data returned by the server. This will be `nil` if the request fails.
     - response: The URL response object providing response metadata, such as HTTP headers and status code.
     - error: An error object that indicates why the request failed, or `nil` if the request was successful.
     */
    public func doPost(baseURLs: [String], path: String?, body: String, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        doRequest(baseURLs: baseURLs, path: path, method: "POST", body: body) { result, response, error in
            let data = result as? Data
            completion(data, response, error)
        }
    }

    /**
     Sends a PUT request to multiple base URLs for a specified path and returns the response data via a completion handler.

     This function attempts to send a PUT request to the provided base URLs in the given order. If a request fails (due to network issues or HTTP error codes between 400 and 599), it will automatically attempt the next URL in the list until all URLs are exhausted or a successful response is received.

     - Parameters:
     - baseURLs: An array of base URL strings to attempt the request from. The function will try each URL in the order provided.
     - path: An optional path component to append to each base URL.
     - body: The string to include as the HTTP body of the request.
     - completion: A closure to be executed once the request is complete. The closure takes three parameters:
     - data: The data returned by the server. This will be `nil` if the request fails.
     - response: The URL response object providing response metadata, such as HTTP headers and status code.
     - error: An error object that indicates why the request failed, or `nil` if the request was successful.
     */
    public func doPut(baseURLs: [String], path: String?, body: String, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        doRequest(baseURLs: baseURLs, path: path, method: "PUT", body: body) { result, response, error in
            let data = result as? Data
            completion(data, response, error)
        }
    }

    /**
     Fetches a list of OpenHAB items from multiple base URLs and returns the items via a completion handler.

     This function attempts to send a GET request to the provided base URLs in the given order to fetch a list of OpenHAB items. If a request fails (due to network issues or HTTP error codes between 400 and 599), it will automatically attempt the next URL in the list until all URLs are exhausted or a successful response is received.

     - Parameters:
     - baseURLs: An array of base URL strings to attempt the request from. The function will try each URL in the order provided.
     - completion: A closure to be executed once the request is complete. The closure takes two parameters:
     - items: An array of `OpenHABItem` objects returned by the server. This will be `nil` if the request fails.
     - error: An error object that indicates why the request failed, or `nil` if the request was successful.
     */
    public func getItems(baseURLs: [String], completion: @escaping ([OpenHABItem]?, Error?) -> Void) {
        doGet(baseURLs: baseURLs, path: "/rest/items") { data, _, error in
            if let error {
                completion(nil, error)
            } else {
                do {
                    var items = [OpenHABItem]()
                    if let data {
                        os_log("getItemsInternal Data: %{public}@", log: .networking, type: .debug, String(data: data, encoding: .utf8) ?? "")
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)

                        let codingDatas = try data.decoded(as: [OpenHABItem.CodingData].self, using: decoder)
                        for codingDatum in codingDatas where codingDatum.openHABItem.type != OpenHABItem.ItemType.group {
                            items.append(codingDatum.openHABItem)
                        }
                        os_log("Loaded items to cache: %{PUBLIC}d", log: .networking, type: .info, items.count)
                    }
                    completion(items, nil)
                } catch {
                    os_log("getItemsInternal ERROR: %{PUBLIC}@", log: .networking, type: .info, String(describing: error))
                    completion(nil, error)
                }
            }
        }
    }

    /**
     Fetches a specific OpenHAB item from multiple base URLs and returns the item via a completion handler.

     This function attempts to send a GET request to the provided base URLs in the given order to fetch a specific OpenHAB item. If a request fails (due to network issues or HTTP error codes between 400 and 599), it will automatically attempt the next URL in the list until all URLs are exhausted or a successful response is received.

     - Parameters:
     - baseURLs: An array of base URL strings to attempt the request from. The function will try each URL in the order provided.
     - itemName: The name of the OpenHAB item to fetch.
     - completion: A closure to be executed once the request is complete. The closure takes two parameters:
     - item: An `OpenHABItem` object returned by the server. This will be `nil` if the request fails.
     - error: An error object that indicates why the request failed, or `nil` if the request was successful.
     */
    public func getItem(baseURLs: [String], itemName: String, completion: @escaping (OpenHABItem?, Error?) -> Void) {
        os_log("getItem from URsL %{public}@ and item %{public}@", log: .networking, type: .info, baseURLs, itemName)
        doGet(baseURLs: baseURLs, path: "/rest/items/\(itemName)") { data, _, error in
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

    /**
     Initiates a download request to multiple base URLs for a specified path and returns the file URL via a completion handler.

     This function attempts to download a file from the provided base URLs in the given order. If a download fails (due to network issues or HTTP error codes between 400 and 599), it will automatically attempt the next URL in the list until all URLs are exhausted or a successful download occurs.

     - Parameters:
     - baseURLs: An array of base URL strings to attempt the download from. The function will try each URL in the order provided.
     - path: The path component to append to each base URL.
     - completionHandler: A closure to be executed once the download is complete. The closure takes three parameters:
     - fileURL: The local URL where the downloaded file is stored. This will be `nil` if the download fails.
     - response: The URL response object providing response metadata, such as HTTP headers and status code.
     - error: An error object that indicates why the request failed, or `nil` if the request was successful.
     */
    public func downloadFile(baseURLs: [String], path: String, completionHandler: @escaping @Sendable (URL?, URLResponse?, (any Error)?) -> Void) {
        doRequest(baseURLs: baseURLs, path: path, method: "GET", download: true) { result, response, error in
            let fileURL = result as? URL
            completionHandler(fileURL, response, error)
        }
    }

    /**
     Initiates a download request to a specified URL and returns the file URL via a completion handler.

     This function sends a GET request to the provided URL to download a file. If the request fails (due to network issues or HTTP error codes between 400 and 599), it will automatically attempt the request again until a successful download occurs.

     - Parameters:
     - url: The URL string to download the file from.
     - completionHandler: A closure to be executed once the download is complete. The closure takes three parameters:
     - fileURL: The local URL where the downloaded file is stored. This will be `nil` if the download fails.
     - response: The URL response object providing response metadata, such as HTTP headers and status code.
     - error: An error object that indicates why the request failed, or `nil` if the request was successful.
     */
    public func downloadFile(url: String, completionHandler: @escaping @Sendable (URL?, URLResponse?, (any Error)?) -> Void) {
        doRequest(baseURLs: [url], path: nil, method: "GET", download: true) { result, response, error in
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

    private func doRequest(baseURLs: [String], path: String?, method: String, body: String? = nil, download: Bool = false, completion: @escaping (Any?, URLResponse?, Error?) -> Void) {
        var urls: [URL] = []
        for urlString in baseURLs {
            if var urlComponent = URLComponents(string: urlString) {
                if let path {
                    urlComponent.path = path
                }
                if let url = urlComponent.url {
                    urls.append(url)
                }
            }
        }

        func sendRequest() {
            guard !urls.isEmpty else {
                os_log("All URLs processed and failed.", log: .networking, type: .error)
                completion(nil, nil, NSError(domain: "HTTPClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "All URLs processed and failed."]))
                return
            }

            let url = urls.removeFirst()
            var request = URLRequest(url: url)
            request.httpMethod = method
            if let body {
                request.httpBody = body.data(using: .utf8)
                request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
            }

            performRequest(request: request, download: download) { result, response, error in
                if let error {
                    os_log("Error with URL %{public}@ : %{public}@", log: .networking, type: .error, url.absoluteString, error.localizedDescription)
                    // Try the next URL
                    sendRequest()
                } else if let response = response as? HTTPURLResponse {
                    if (400 ... 599).contains(response.statusCode) {
                        os_log("HTTP error from URL %{public}@ : %{public}d", log: .networking, type: .error, url.absoluteString, response.statusCode)
                        // Try the next URL
                        sendRequest()
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

    // MARK: - URLSessionDelegate for Client Certificates and Basic Auth
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        urlSessionInternal(session, task: nil, didReceive: challenge, completionHandler: completionHandler)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        urlSessionInternal(session, task: task, didReceive: challenge, completionHandler: completionHandler)
    }

    private func urlSessionInternal(_ session: URLSession, task: URLSessionTask?, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        os_log("URLAuthenticationChallenge: %{public}@", log: .networking, type: .info, challenge.protectionSpace.authenticationMethod)
        let authenticationMethod = challenge.protectionSpace.authenticationMethod
        switch authenticationMethod {
        case NSURLAuthenticationMethodServerTrust:
            handleServerTrust(challenge: challenge, completionHandler: completionHandler)
        case NSURLAuthenticationMethodDefault, NSURLAuthenticationMethodHTTPBasic:
            if let task {
                task.authAttemptCount += 1
                if task.authAttemptCount > 1 {
                    completionHandler(.cancelAuthenticationChallenge, nil)
                } else {
                    handleBasicAuth(challenge: challenge, completionHandler: completionHandler)
                }
            } else {
                handleBasicAuth(challenge: challenge, completionHandler: completionHandler)
            }
        case NSURLAuthenticationMethodClientCertificate:
            handleClientCertificateAuth(challenge: challenge, completionHandler: completionHandler)
        default:
            completionHandler(.performDefaultHandling, nil)
        }
    }

    private func handleServerTrust(challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
    }

    private func handleBasicAuth(challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let credential = URLCredential(user: username, password: password, persistence: .forSession)
        completionHandler(.useCredential, credential)
    }

    private func handleClientCertificateAuth(challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let certificateManager = ClientCertificateManager()
        let (disposition, credential) = certificateManager.evaluateTrust(with: challenge)
        completionHandler(disposition, credential)
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
