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

private enum HTTPClientError: Error {
    case serverTrustEvaluationFailed(reason: String)
    case noDataforItem
    case noDataForProperties
    case baseURLIsNil
    case httpError(Int)
    case couldNotRegister
    case couldNotLoadNotification
    case failedtoFetchMJPEG

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
        case .couldNotRegister:
            "Could not register"
        case .couldNotLoadNotification:
            "Could not load notification"
        case .failedtoFetchMJPEG:
            "Failed to fetch MJPEG"
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

    public enum SessionType {
        case download
        case data
        case bytes
    }

    // this can be changed if we detect another server
    public var baseURL: URL?

    public var session: URLSession!
    private let username: String
    private let password: String
    private let alwaysSendBasicAuth: Bool
    private let ignoreSSL: Bool
    private var evaluateContinuation: CheckedContinuation<CertificateEvaluateResult, Never>?
    private var trustedCertificates: [String: Data] = [:]
    private var authAttemptCounts = [URLSessionTask: Int]()

    private let logger = Logger(subsystem: "org.openhab.core", category: "HTTPClient")

    public init(baseURL: URL? = nil, username: String = "", password: String = "", alwaysSendBasicAuth: Bool = false, ignoreSSL: Bool = false) {
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

    public func processStream(url: URL) async throws -> (URLSession.AsyncBytes, URLResponse) {
        do {
            return try await doRequest(baseURL: url, type: .bytes)
        } catch {
            os_log("Failed to fetch MJPEG stream: %@", log: .default, type: .error, error.localizedDescription)
            throw HTTPClientError.failedtoFetchMJPEG
        }
    }

    @discardableResult
    public func register(prefsURL: String,
                         deviceToken: String,
                         deviceId: String,
                         deviceName: String) async throws -> Data? {
        if let url = Endpoint.appleRegistration(prefsURL: prefsURL, deviceToken: deviceToken, deviceId: deviceId, deviceName: deviceName).url {
            let (data, _): (Data, URLResponse) = try await doRequest(baseURL: url, type: .data)
            return data
        } else {
            throw HTTPClientError.couldNotRegister
        }
    }

    public func notification(urlString: String) async throws -> Data {
        if let url = Endpoint.notification(prefsURL: urlString).url {
            let (data, _): (Data, URLResponse) = try await doRequest(baseURL: url, type: .data)
            return data
        } else {
            throw HTTPClientError.couldNotLoadNotification
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
        let (fileURL, response): (URL, URLResponse) = try await doRequest(baseURL: url, path: nil, type: .download)

        return (fileURL, response)
    }

    public func doRequest<T>(baseURL: URL?,
                             path: String? = nil,
                             headers: [String: String]? = nil,
                             timeout: TimeInterval = 60.0,
                             body: String? = nil,
                             type: SessionType,
                             cacheingPolicy: URLRequest.CachePolicy = .useProtocolCachePolicy) async throws -> (T, URLResponse) {
        guard var url = baseURL ?? self.baseURL else {
            os_log("doRequest ERROR: Base URL is nil", log: .networking, type: .info)
            throw HTTPClientError.baseURLIsNil
        }

        if let path {
            url.appendPathComponent(path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
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

        if cacheingPolicy != .useProtocolCachePolicy {
            request.cachePolicy = cacheingPolicy
        }

        let (result, response): (T, URLResponse) = try await performRequest(request: request, type: type)
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

    private func performRequest<T>(request: URLRequest, type: SessionType = .data) async throws -> (T, URLResponse) {
        var request = request
        if alwaysSendBasicAuth {
            request.setValue(basicAuthHeader(), forHTTPHeaderField: "Authorization")
        }

        switch type {
        case .download:
            return try await session.download(for: request) as! (T, URLResponse)
        case .data:
            return try await session.data(for: request) as! (T, URLResponse)
        case .bytes:
            return try await session.bytes(for: request) as! (T, URLResponse)
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

    private func getPersistencePath() -> URL {
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
            try data.write(to: getPersistencePath())
        } catch {
            os_log("Could not save trusted certificates", log: .default)
        }
    }

    private func loadTrustedCertificates() {
        var decodableTrustedCertificates: [String: Data] = [:]
        do {
            let rawdata = try Data(contentsOf: getPersistencePath())
            let decoder = PropertyListDecoder()
            decodableTrustedCertificates = try decoder.decode([String: Data].self, from: rawdata)
            trustedCertificates = decodableTrustedCertificates
        } catch {
            // if Decodable fails, fall back to NSKeyedArchiver
            do {
                let rawdata = try Data(contentsOf: getPersistencePath())
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
        var error: CFError?
        _ = SecTrustEvaluateWithError(serverTrust, &error)
        SecTrustGetTrustResult(serverTrust, &result)
        logger.info("Trust evaluation result: \(result.rawValue), error: \(String(describing: error))")

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
