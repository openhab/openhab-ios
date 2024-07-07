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

public class HTTPClient: NSObject, URLSessionDelegate {
    // MARK: - Properties

    private var session: URLSession!
    private let username: String
    private let password: String
    private let certManager: ClientCertificateManager
    private let alwaysSendBasicAuth: Bool

    public init(username: String, password: String, alwaysSendBasicAuth: Bool = false) {
        self.username = username
        self.password = password
        certManager = ClientCertificateManager()
        self.alwaysSendBasicAuth = alwaysSendBasicAuth
        super.init()

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60

        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - URLSessionDelegate for Client Certificates

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            let serverDistinguishedNames = challenge.protectionSpace.distinguishedNames
            let identity = certManager.evaluateTrust(distinguishedNames: serverDistinguishedNames ?? [])

            if let identity {
                let credential = URLCredential(identity: identity, certificates: nil, persistence: .forSession)
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let serverTrust = challenge.protectionSpace.serverTrust!
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic {
            let credential = URLCredential(user: username, password: password, persistence: .forSession)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    public func doGet(baseURLs: [String], path: String?, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        doRequest(baseURLs: baseURLs, path: path, method: "GET", completion: completion)
    }

    public func doPost(baseURLs: [String], path: String?, body: String, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        doRequest(baseURLs: baseURLs, path: path, method: "POST", body: body, completion: completion)
    }

    public func doPut(baseURLs: [String], path: String?, body: String, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        doRequest(baseURLs: baseURLs, path: path, method: "PUT", body: body, completion: completion)
    }

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

                        // if we are hitting an item, then its OpenHABItem.CodingData] not [OpenHABItem.CodingData]
                        let codingDatas = try data.decoded(as: [OpenHABItem.CodingData].self, using: decoder)
                        for codingDatum in codingDatas where codingDatum.openHABItem.type != OpenHABItem.ItemType.group {
                            items.append(codingDatum.openHABItem)
                        }
                        os_log("Loaded items to cache: %{public}d", log: .networking, type: .info, items.count)
                    }
                    completion(items, nil)
                } catch {
                    os_log("getItemsInternal ERROR: %{public}@", log: .networking, type: .info, String(describing: error))
                    completion(nil, error)
                }
            }
        }
    }

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
                    os_log("getItemsInternal ERROR: %{public}@", log: .networking, type: .info, String(describing: error))
                    completion(nil, error)
                }
            }
        }
    }

    public func downloadFile(url: URL, completionHandler: @escaping @Sendable (URL?, URLResponse?, (any Error)?) -> Void) {
        let task = session.downloadTask(with: url, completionHandler: completionHandler)
        task.resume()
    }

    // MARK: - Private Methods

    // MARK: - Basic Authentication

    private func basicAuthHeader() -> String {
        let authString = "\(username):\(password)"
        let authData = authString.data(using: .utf8)!
        return "Basic \(authData.base64EncodedString())"
    }

    // Perform an HTTP request
    private func performRequest(request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        var request = request
        if alwaysSendBasicAuth {
            request.setValue(basicAuthHeader(), forHTTPHeaderField: "Authorization")
        }
        let task = session.dataTask(with: request, completionHandler: completion)
        task.resume()
    }

    // General function to perform HTTP requests
    private func doRequest(baseURLs: [String], path: String?, method: String, body: String? = nil, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
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
                request.httpBody = body.data(using: .utf8)!
                request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
            }

            performRequest(request: request) { data, response, error in
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
                        if let data {
                            os_log("Data: %{public}@", log: .networking, type: .debug, String(data: data, encoding: .utf8) ?? "")
                        }
                        completion(data, response, nil)
                    }
                }
            }
        }
        sendRequest()
    }
}
