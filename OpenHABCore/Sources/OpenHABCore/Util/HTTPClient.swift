// Copyright (c) 2010-2025 Contributors to the openHAB project
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
import os

private let logger = Logger(subsystem: "org.openhab.core", category: "HTTPClient")

private enum HTTPClientError: Error {
    case serverTrustEvaluationFailed(reason: String)
    case noDataforItem
    case noDataForProperties
    case baseURLIsNil
    case httpError(Int)

    var debugDescription: String {
        switch self {
        case .noDataforItem:
            "No data for item"
        case let .serverTrustEvaluationFailed(reason):
            "server trust evaluation failed: \(reason)"
        case .noDataForProperties:
            "No data for properties"
        case .baseURLIsNil:
            "Base URL is nil"
        case let .httpError(statusCode):
            "HTTP error \(statusCode)"
        }
    }
}

public class HTTPClient: NSObject {
    // MARK: - Properties

    public enum CertificateEvaluateResult {
        case undecided
        case deny
        case permitOnce
        case permitAlways
    }

    // this can be changed if we detect another server
    public var baseURL: URL?

    private var session: URLSession!
    private let username: String
    private let password: String
    private let alwaysSendBasicAuth: Bool
    private let ignoreSSL: Bool
    private var evaluateContinuation: CheckedContinuation<CertificateEvaluateResult, Never>?
    private var trustedCertificates: [String: Data] = [:]
    private var authAttemptCounts = [URLSessionTask: Int]()

    public init(baseURL: URL? = nil, username: String, password: String, alwaysSendBasicAuth: Bool = false, ignoreSSL: Bool = false) {
        self.baseURL = baseURL
        self.username = username
        self.password = password
        self.alwaysSendBasicAuth = alwaysSendBasicAuth
        self.ignoreSSL = ignoreSSL
        super.init()

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 60

        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        initializeCertificatesStore()
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
    public func doPost(baseURL: URL? = nil, path: String?, body: String, completion: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionTask? {
        doRequest(baseURL: baseURL, path: path, method: "POST", body: body) { result, response, error in
            let data = result as? Data
            completion(data, response, error)
        }
    }

    /**
      Initiates a download request to a specified base URL for a specified path and returns the file URL via a completion handler.

      - Parameters:
     - url
      - Returns:
      - response: The URL response object providing response metadata, such as HTTP headers and status code.
      - error: An error object that indicates why the request failed, or `nil` if the request was successful.
      */

    public func downloadFile(url: URL) async throws -> (URL, URLResponse) {
        let (result, response) = try await doRequest(baseURL: url, path: nil, method: "GET", download: true)

        let fileURL = result as? URL

        guard let fileURL1 = fileURL else {
            fatalError("Expected non-nil result 'fileURL1' in the non-error case")
        }
        guard let response1 = response else {
            fatalError("Expected non-nil result 'response1' in the non-error case")
        }
        return (fileURL1, response1)
    }

    public func sendCommand(url: URL? = nil, itemName: String, command: String, completion: @escaping (String?, Error?) -> Void) -> URLSessionTask? {
        os_log("sendCommand  %{public}@  %{public}@", log: .default, type: .debug, command, itemName)
        return doPost(baseURL: url, path: "/rest/items/\(itemName)", body: command) { data, _, error in
            if let error {
                os_log("Could not send data %{public}@", log: .default, type: .error, error.localizedDescription)
                completion(nil, error)
            } else {
                os_log("Request succeeded", log: .default, type: .info)
                var returnValue = ""
                if let data {
                    returnValue = String(data: data, encoding: .utf8) ?? ""
                    os_log("Data: %{public}@", log: .default, type: .debug, returnValue)
                }
                completion(returnValue, nil)
            }
        }
    }

    public func loadSitemapData(url: URL? = nil,
                                longPolling: Bool,
                                refresh: Bool,
                                completion: @escaping (Data?, Error?) -> Void) -> URLSessionTask? {
        let timeout: TimeInterval = longPolling ? 35.0 : 10.0 // for long polling, the server will return in 30 seconds
        var headers: [String: String] = [:]
        if longPolling {
            headers["X-Atmosphere-Transport"] = "0"
        }

        os_log("Fetching page from URL %{public}@", log: .networking, type: .info, url?.absoluteString ?? "")

        return doRequest(baseURL: url, path: nil, method: "GET", headers: headers, timeout: timeout) { result, _, error in
            if let error {
                os_log("error fetching page from URL %{public}@ %{public}@", log: .networking, type: .error, url?.absoluteString ?? "", error.localizedDescription)
                completion(nil, error)
            } else if let data = result as? Data {
                os_log("Finsihed Fetching page from URL %{public}@", log: .networking, type: .info, url?.absoluteString ?? "")
                completion(data, nil)
            } else {
                os_log("No data from URL %{public}@", log: .networking, type: .error, url?.absoluteString ?? "")
                completion(nil, URLError(.unknown, userInfo: [NSLocalizedDescriptionKey: "No valid data received from server."]))
            }
        }
    }

    public func doRequest(baseURL: URL?, path: String?, method: String, headers: [String: String]? = nil,
                          timeout: TimeInterval = 60.0, body: String? = nil, download: Bool = false, completion: @escaping (Any?, URLResponse?, Error?) -> Void) -> URLSessionTask? {
        guard var url = baseURL ?? self.baseURL else {
            os_log("doRequest ERROR: Base URL is nil", log: .networking, type: .info)
            completion(nil, nil, HTTPClientError.baseURLIsNil)
            return nil
        }

        if let path {
            url.appendPathComponent(path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        if let headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        if let body {
            request.httpBody = body.data(using: .utf8)
            request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        }
        return performRequest(request: request, download: download) { result, response, error in
            if let error {
                os_log("Error with URL %{public}@ : %{public}@", log: .networking, type: .error, url.absoluteString, error.localizedDescription)
                completion(nil, response, error)
            } else if let response = response as? HTTPURLResponse {
                if (400 ... 599).contains(response.statusCode) {
                    os_log("HTTP error from URL %{public}@ : %{public}d", log: .networking, type: .error, url.absoluteString, response.statusCode)
                    completion(nil, response, HTTPClientError.httpError(response.statusCode))
                } else {
                    os_log("Response from URL %{public}@ : %{public}d", log: .networking, type: .info, url.absoluteString, response.statusCode)
                    completion(result, response, nil)
                }
            }
        }
    }

    public func doRequest(baseURL: URL?,
                          path: String?,
                          method: String,
                          headers: [String: String]? = nil,
                          timeout: TimeInterval = 60.0,
                          body: String? = nil,
                          download: Bool = false) async throws -> (Any?, URLResponse?) {
        guard var url = baseURL ?? self.baseURL else {
            os_log("doRequest ERROR: Base URL is nil", log: .networking, type: .info)
            throw HTTPClientError.baseURLIsNil
        }

        if let path {
            url.appendPathComponent(path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        if let headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        if let body {
            request.httpBody = body.data(using: .utf8)
            request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        }

        let (result, response) = try await performRequest(request: request, download: download)
        if let response = response as? HTTPURLResponse {
            if (400 ... 599).contains(response.statusCode) {
                os_log("HTTP error from URL %{public}@ : %{public}d", log: .networking, type: .error, url.absoluteString, response.statusCode)
                throw HTTPClientError.httpError(response.statusCode)
            } else {
                os_log("Response from URL %{public}@ : %{public}d", log: .networking, type: .info, url.absoluteString, response.statusCode)
                return (result, response)
            }
        }
        fatalError()
    }

    private func performRequest(request: URLRequest, download: Bool, completion: @escaping (Any?, URLResponse?, Error?) -> Void) -> URLSessionTask? {
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
        return task
    }

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

    // MARK: - Basic Authentication

    private func basicAuthHeader() -> String {
        let authString = "\(username):\(password)"
        let authData = authString.data(using: .utf8)!
        return "Basic \(authData.base64EncodedString())"
    }

    // MARK: - SSL Certificate Handling

    private func initializeCertificatesStore() {
        os_log("Initializing cert store", log: .default, type: .info)
        loadTrustedCertificates()
        if trustedCertificates.isEmpty {
            os_log("No cert store, creating", log: .default, type: .info)
            trustedCertificates = [:]
            saveTrustedCertificates()
        } else {
            os_log("Loaded existing cert store", log: .default, type: .info)
        }
    }

    private func getPersistensePath() -> URL {
        #if os(watchOS)
        let documentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return URL(fileURLWithPath: documentsDirectory).appendingPathComponent("trustedCertificates")
        #else
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.openhab.app")!.appendingPathComponent("trustedCertificates")
        #endif
    }

    private func saveTrustedCertificates() {
        do {
            let data = try PropertyListEncoder().encode(trustedCertificates)
            try data.write(to: getPersistensePath())
        } catch {
            os_log("Could not save trusted certificates", log: .default)
        }
    }

    private func loadTrustedCertificates() {
        var decodableTrustedCertificates: [String: Data] = [:]
        do {
            let rawdata = try Data(contentsOf: getPersistensePath())
            let decoder = PropertyListDecoder()
            decodableTrustedCertificates = try decoder.decode([String: Data].self, from: rawdata)
            trustedCertificates = decodableTrustedCertificates
        } catch {
            // if Decodable fails, fall back to NSKeyedArchiver
            do {
                let rawdata = try Data(contentsOf: getPersistensePath())
                if let unarchivedTrustedCertificates = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSDictionary.self, NSString.self, NSData.self], from: rawdata) as? [String: Data] {
                    trustedCertificates = unarchivedTrustedCertificates
                    saveTrustedCertificates() // Ensure that data is written in new format
                }
            } catch {
                os_log("Could not load trusted certificates", log: .default)
            }
        }
    }

    private func storeCertificateData(_ certificate: CFData?, forDomain domain: String) {
        let certificateData = certificate as Data?
        trustedCertificates[domain] = certificateData
        saveTrustedCertificates()
    }

    private func certificateData(forDomain domain: String) -> CFData? {
        guard let certificateData = trustedCertificates[domain] else { return nil }
        return certificateData as CFData
    }

    private func getLeafCertificate(trust: SecTrust?) -> SecCertificate? {
        if let trust, SecTrustGetCertificateCount(trust) > 0,
           let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate] {
            return certificates[0]
        }
        return nil
    }

    private func waitForEvaluation() async -> CertificateEvaluateResult {
        await withCheckedContinuation { continuation in
            evaluateContinuation = continuation
        }
    }

    public func completeEvaluation(_ result: CertificateEvaluateResult) {
        logger.info("Completing evaluation with result: \(String(describing: result))")
        evaluateContinuation?.resume(returning: result)
        evaluateContinuation = nil
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
                authAttemptCounts[task, default: 0] += 1
                if authAttemptCounts[task]! > 1 {
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
        let domain = challenge.protectionSpace.host
        logger.info("Handling server trust for domain: \(domain)")

        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            logger.error("No server trust object available")
            return (.cancelAuthenticationChallenge, nil)
        }

        var result: SecTrustResultType = .invalid
        if #available(iOS 12.0, *) {
            var error: CFError?
            _ = SecTrustEvaluateWithError(serverTrust, &error)
            SecTrustGetTrustResult(serverTrust, &result)
            logger.info("Trust evaluation result: \(result.rawValue), error: \(String(describing: error))")
        } else {
            SecTrustEvaluate(serverTrust, &result)
            logger.info("Trust evaluation result: \(result.rawValue)")
        }

        if result.isAny(of: .unspecified, .proceed) || ignoreSSL {
            logger.info("Certificate is trusted or SSL verification ignored")
            return (.useCredential, URLCredential(trust: serverTrust))
        }

        guard let certificate = getLeafCertificate(trust: serverTrust) else {
            logger.error("Could not get leaf certificate")
            return (.cancelAuthenticationChallenge, nil)
        }

        let certificateSummary = SecCertificateCopySubjectSummary(certificate)
        let certificateData = SecCertificateCopyData(certificate)

        // If we have a certificate for this domain
        if let previousCertificateData = self.certificateData(forDomain: domain) {
            if CFEqual(previousCertificateData, certificateData) {
                logger.info("Using previously trusted certificate for domain: \(domain)")
                return (.useCredential, URLCredential(trust: serverTrust))
            } else {
                logger.warning("Certificate mismatch detected for domain: \(domain)")
                // Certificate mismatch - possible MitM attack
                NotificationCenter.default.post(
                    name: .evaluateCertificateMismatch,
                    object: self,
                    userInfo: ["summary": certificateSummary as Any, "domain": domain]
                )
                let evaluateResult = await waitForEvaluation()
                logger.info("User decision for certificate mismatch: \(String(describing: evaluateResult))")

                switch evaluateResult {
                case .deny:
                    return (.cancelAuthenticationChallenge, nil)
                case .permitOnce:
                    return (.useCredential, URLCredential(trust: serverTrust))
                case .permitAlways:
                    storeCertificateData(certificateData, forDomain: domain)
                    NotificationCenter.default.post(name: .acceptedServerCertificatesChanged, object: self)
                    return (.useCredential, URLCredential(trust: serverTrust))
                case .undecided:
                    return (.cancelAuthenticationChallenge, nil)
                }
            }
        }

        // New certificate
        logger.info("New untrusted certificate for domain: \(domain)")
        NotificationCenter.default.post(
            name: .evaluateServerTrust,
            object: self,
            userInfo: ["summary": certificateSummary as Any, "domain": domain]
        )
        let evaluateResult = await waitForEvaluation()
        logger.info("User decision for new certificate: \(String(describing: evaluateResult))")

        switch evaluateResult {
        case .deny:
            return (.cancelAuthenticationChallenge, nil)
        case .permitOnce:
            return (.useCredential, URLCredential(trust: serverTrust))
        case .permitAlways:
            storeCertificateData(certificateData, forDomain: domain)
            NotificationCenter.default.post(name: .acceptedServerCertificatesChanged, object: self)
            return (.useCredential, URLCredential(trust: serverTrust))
        case .undecided:
            return (.cancelAuthenticationChallenge, nil)
        }
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

public extension Notification.Name {
    static let evaluateServerTrust = Notification.Name("evaluateServerTrust")
    static let evaluateCertificateMismatch = Notification.Name("evaluateCertificateMismatch")
    static let acceptedServerCertificatesChanged = Notification.Name("acceptedServerCertificatesChanged")
}
