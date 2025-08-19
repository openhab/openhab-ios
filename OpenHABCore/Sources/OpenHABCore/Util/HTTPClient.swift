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

@preconcurrency import Foundation
import os

private let logger = Logger(subsystem: "org.openhab", category: "HTTPClient")

public enum HTTPClientError: Error {
    case serverTrustEvaluationFailed(reason: String)
    case noDataforItem
    case noDataForProperties
    case baseURLIsNil
    case httpError(Int)
    case couldNotRegister
    case couldNotLoadNotification
    case failedtoFetchMJPEG
    case noConfiguration

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
        case .noConfiguration:
            "No configuration"
        }
    }
}

public enum CertificateEvaluateResult: Sendable {
    case undecided
    case deny
    case permitOnce
    case permitAlways
}

actor CertificateStore {
    private var trustedCertificates: [String: Data] = [:]

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
            logger.info("Could not save trusted certificates")
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
                logger.info("Could not load trusted certificates")
            }
        }
    }

    private func initializeCertificatesStore() {
        logger.info("Initializing cert store")
        loadTrustedCertificates()
        if trustedCertificates.isEmpty {
            logger.info("No cert store, creating")
            trustedCertificates = [:]
            saveTrustedCertificates()
        } else {
            logger.info("Loaded existing cert store")
        }
    }

    public func storeCertificateData(_ certificate: Data?, forDomain domain: String) {
        trustedCertificates[domain] = certificate
        saveTrustedCertificates()
    }

    public func certificateData(forDomain domain: String) -> Data? {
        guard let data = trustedCertificates[domain] else { return nil }
        return data
    }
}

public final class HTTPClient: NSObject, Sendable {
    // MARK: - Properties

    public enum SessionType {
        case download
        case data
        case bytes
    }

    // this can be changed if we detect another server
    public let baseURL: URL?

    private let logger = Logger(subsystem: "org.openhab.core", category: "HTTPClient")

    private let configuration: ConnectionConfiguration
    public let session: URLSession
    public let delegate: HTTPClientDelegate

    public init(baseURL: URL? = nil, configuration: ConnectionConfiguration) {
        self.configuration = configuration
        self.baseURL = baseURL
        delegate = HTTPClientDelegate(with: configuration)
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        super.init()
    }

    public func processStream(url: URL) async throws -> (URLSession.AsyncBytes, URLResponse) {
        do {
            return try await doRequest(baseURL: url, type: .bytes)
        } catch {
            logger.error("Failed to fetch MJPEG stream: \(error.localizedDescription)")
            throw HTTPClientError.failedtoFetchMJPEG
        }
    }

    @discardableResult
    public func register(prefsURL: String,
                         deviceToken: String,
                         deviceId: String,
                         deviceName: String) async throws -> String? {
        if let url = Endpoint.appleRegistration(prefsURL: prefsURL, deviceToken: deviceToken, deviceId: deviceId, deviceName: deviceName).url {
            let (data, _): (Data, URLResponse) = try await doRequest(baseURL: url, type: .data)
            struct CloudUserResponse: Decodable { let userId: String }
            return try? JSONDecoder().decode(CloudUserResponse.self, from: data).userId
        } else {
            throw HTTPClientError.couldNotRegister
        }
    }

    public func notification(url: URL) async throws -> Data {
        let (data, _): (Data, URLResponse) = try await doRequest(baseURL: url, type: .data)
        return data
    }

    public func notification(urlString: String) async throws -> [OpenHABNotification] {
        guard let url = Endpoint.notification(prefsURL: urlString).url else { throw HTTPClientError.couldNotLoadNotification }
        let data = try await notification(url: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)
        let codingDatas = try data.decoded(as: [OpenHABNotification.CodingData].self, using: decoder)
        return codingDatas.map(\.openHABNotification)
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
            logger.info("doRequest ERROR: Base URL is nil")
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
                logger.error("HTTP error from URL \(url.absoluteString) : \(response.statusCode)")
                throw HTTPClientError.httpError(response.statusCode)
            } else {
                logger.info("Response from URL \(url.absoluteString) : \(response.statusCode)")
                return (result, response)
            }
        }
        fatalError()
    }

    private func performRequest<T>(request: URLRequest, type: SessionType = .data) async throws -> (T, URLResponse) {
        var request = request

        let username = configuration.username
        let password = configuration.password
        let alwaysSendBasicAuth = configuration.alwaysSendBasicAuth

        if request.url?.host?.hasSuffix("myopenhab.org") == true || alwaysSendBasicAuth, !username.isEmpty, !password.isEmpty {
            request.setValue(basicAuthHeader(username: username, password: password), forHTTPHeaderField: "Authorization")
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
}

public extension Notification.Name {
    static let evaluateServerTrust = Notification.Name("evaluateServerTrust")
    static let evaluateCertificateMismatch = Notification.Name("evaluateCertificateMismatch")
    static let acceptedServerCertificatesChanged = Notification.Name("acceptedServerCertificatesChanged")
}
