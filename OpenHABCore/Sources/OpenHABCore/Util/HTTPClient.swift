// Copyright (c) 2010-2026 Contributors to the openHAB project
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

public struct CertificateEntry: Codable, Sendable {
    public let data: Data
    public let dateAccepted: Date

    public init(data: Data, dateAccepted: Date = Date()) {
        self.data = data
        self.dateAccepted = dateAccepted
    }
}

public actor CertificateStore {
    public static let shared = CertificateStore()

    private var trustedCertificates: [String: CertificateEntry] = [:]
    private let persistencePath: URL?

    /// Creates a CertificateStore with the default persistence path (app group or documents directory)
    public init() {
        // Calculate the default persistence path
        let path: URL
        #if os(watchOS)
        let documentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        path = URL(fileURLWithPath: documentsDirectory).appendingPathComponent("trustedCertificates")
        #else
        // Try app group container first, fall back to documents directory for testing
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.org.openhab.app") {
            path = appGroupURL.appendingPathComponent("trustedCertificates")
        } else {
            // Fallback for test environment where app group may not be available
            let documentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            path = URL(fileURLWithPath: documentsDirectory).appendingPathComponent("trustedCertificates")
        }
        #endif

        persistencePath = path
        let (certificates, needsMigration) = Self.loadCertificates(from: path)
        trustedCertificates = certificates

        // If migration occurred, persist the new format
        if needsMigration {
            Task {
                await self.saveTrustedCertificates()
                Logger.httpClient.info("Migration completed, saved in new format")
            }
        }
    }

    /// Creates a CertificateStore for testing with an optional custom persistence path.
    /// Pass `nil` for in-memory only operation (no file I/O).
    public init(persistencePath: URL?) {
        self.persistencePath = persistencePath
        if let path = persistencePath {
            let (certificates, needsMigration) = Self.loadCertificates(from: path)
            trustedCertificates = certificates

            // If migration occurred, persist the new format
            if needsMigration {
                Task {
                    await self.saveTrustedCertificates()
                    Logger.httpClient.info("Migration completed, saved in new format")
                }
            }
        } else {
            trustedCertificates = [:]
        }
    }

    /// Loads certificates from a given path (static to be called from init)
    /// Returns a tuple of (certificates, needsMigration) where needsMigration indicates if the data was in an old format
    private static func loadCertificates(from path: URL) -> (certificates: [String: CertificateEntry], needsMigration: Bool) {
        Logger.httpClient.info("Initializing cert store")
        Logger.httpClient.debug("Attempting to load certificates from \(path)")

        do {
            let rawdata = try Data(contentsOf: path)
            let decoder = PropertyListDecoder()

            // Try to load new format first
            do {
                let certificates = try decoder.decode([String: CertificateEntry].self, from: rawdata)
                let certCount = certificates.count
                Logger.httpClient.info("Loaded existing cert store (new format) with \(certCount) certificates")
                return (certificates, false)
            } catch {
                // Fall back to old format
                let oldFormat = try decoder.decode([String: Data].self, from: rawdata)
                Logger.httpClient.info("Migrating cert store from old format with \(oldFormat.count) certificates")

                // Convert old format to new format with current date
                let migrationDate = Date()
                var certificates: [String: CertificateEntry] = [:]
                for (domain, data) in oldFormat {
                    certificates[domain] = CertificateEntry(data: data, dateAccepted: migrationDate)
                }
                return (certificates, true)
            }
        } catch {
            // if Decodable fails, fall back to NSKeyedArchiver for very old format
            do {
                let rawdata = try Data(contentsOf: path)
                if let unarchivedTrustedCertificates = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSDictionary.self, NSString.self, NSData.self], from: rawdata) as? [String: Data] {
                    Logger.httpClient.info("Migrating cert store from NSKeyedArchiver format")

                    // Convert old format to new format with current date
                    let migrationDate = Date()
                    var certificates: [String: CertificateEntry] = [:]
                    for (domain, data) in unarchivedTrustedCertificates {
                        certificates[domain] = CertificateEntry(data: data, dateAccepted: migrationDate)
                    }
                    return (certificates, true)
                }
            } catch {
                // File doesn't exist or can't be read
            }
            Logger.httpClient.info("No cert store, creating")
            return ([:], false)
        }
    }

    // swiftlint:disable:next async_without_await
    private func saveTrustedCertificates() async {
        guard let path = persistencePath else {
            // In-memory mode, no persistence
            return
        }

        do {
            let data = try PropertyListEncoder().encode(trustedCertificates)

            // Ensure parent directory exists
            let parentDir = path.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)

            // Write data with explicit options to ensure it's flushed to disk
            try data.write(to: path, options: [.atomic])

            // Double-check the file was written and can be read back
            let verifyData = try Data(contentsOf: path)
            guard verifyData == data else {
                Logger.httpClient.error("Data verification failed after write")
                return
            }

            Logger.httpClient.debug("Successfully saved and verified trusted certificates to \(path)")

        } catch {
            Logger.httpClient.error("Could not save trusted certificates: \(error)")
        }
    }

    public func storeCertificateData(_ certificate: Data?, forDomain domain: String) async {
        if let certificate {
            trustedCertificates[domain] = CertificateEntry(data: certificate, dateAccepted: Date())
            Logger.httpClient.debug("Stored certificate for domain \(domain), size: \(certificate.count) bytes")
        } else {
            trustedCertificates[domain] = nil
            Logger.httpClient.debug("Removed certificate for domain \(domain)")
        }
        await saveTrustedCertificates()
    }

    // swiftlint:disable:next async_without_await
    public func certificateData(forDomain domain: String) async -> Data? {
        let data = trustedCertificates[domain]?.data
        Logger.httpClient.debug("Retrieved certificate for domain \(domain): \(data?.count ?? 0) bytes")
        return data
    }

    // swiftlint:disable:next async_without_await
    public func getAllCertificates() async -> [String: CertificateEntry] {
        trustedCertificates
    }

    // swiftlint:disable:next async_without_await
    public func getCertificateInfo(forDomain domain: String) async -> CertificateEntry? {
        trustedCertificates[domain]
    }

    public func removeCertificate(forDomain domain: String) async {
        trustedCertificates.removeValue(forKey: domain)
        await saveTrustedCertificates()
    }
}

public final class HTTPClient: NSObject, Sendable {
    // MARK: - Properties

    public enum SessionType {
        case download
        case data
        case bytes
        case mjpegStream
    }

    // this can be changed if we detect another server
    public let baseURL: URL?

    private let connectionConfiguration: ConnectionConfiguration
    public let session: URLSession
    public let sessionConfiguration: URLSessionConfiguration
    public let delegate: (any URLSessionDelegate)?

    /// Creates HTTPClient with default session configuration and HTTPClientDelegate
    public convenience init(baseURL: URL? = nil, connectionConfiguration: ConnectionConfiguration) {
        self.init(
            baseURL: baseURL,
            connectionConfiguration: connectionConfiguration,
            sessionConfiguration: .default,
            delegate: HTTPClientDelegate(with: connectionConfiguration)
        )
    }

    /// Creates HTTPClient with custom session configuration and optional delegate
    public init(baseURL: URL? = nil, connectionConfiguration: ConnectionConfiguration, sessionConfiguration: URLSessionConfiguration,
                delegate: (any URLSessionDelegate)? = nil) {
        self.baseURL = baseURL
        self.delegate = delegate
        self.connectionConfiguration = connectionConfiguration
        self.sessionConfiguration = sessionConfiguration
        session = URLSession(
            configuration: sessionConfiguration,
            delegate: delegate,
            delegateQueue: nil
        )
        super.init()
    }

    /// Creates HTTPClient optimized for streaming with modified session configuration
    public convenience init(streamingWith sessionConfiguration: URLSessionConfiguration,
                            baseURL: URL? = nil,
                            connectionConfiguration: ConnectionConfiguration,
                            delegate: (any URLSessionDelegate)? = nil) {
        let streamingSessionConfiguration = (sessionConfiguration.copy() as? URLSessionConfiguration) ?? .ephemeral
        streamingSessionConfiguration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        streamingSessionConfiguration.timeoutIntervalForRequest = 0
        streamingSessionConfiguration.waitsForConnectivity = true
        streamingSessionConfiguration.urlCache = nil

        self.init(
            baseURL: baseURL,
            connectionConfiguration: connectionConfiguration,
            sessionConfiguration: streamingSessionConfiguration,
            delegate: delegate
        )
    }

    public func processStream(url: URL) async throws -> (Data, URLResponse) {
        do {
            return try await doRequest(baseURL: url, type: .mjpegStream)
        } catch {
            Logger.httpClient.error("Failed to fetch MJPEG stream: \(error.localizedDescription)")
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
        }
        throw HTTPClientError.couldNotRegister
    }

    public func notification(url: URL) async throws -> Data {
        let (data, _): (Data, URLResponse) = try await doRequest(baseURL: url, type: .data)
        return data
    }

    public func notification(urlString: String) async throws -> [OpenHABNotification] {
        guard let url = Endpoint.notification(prefsURL: urlString).url else { throw HTTPClientError.couldNotLoadNotification }
        let data = try await notification(url: url)

        let decoder = JSONDecoder.makeISO8601TolerantDecoder()
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
                             method: String = "GET",
                             type: SessionType,
                             cacheingPolicy: URLRequest.CachePolicy = .useProtocolCachePolicy) async throws -> (T, URLResponse) {
        guard var url = baseURL ?? self.baseURL else {
            Logger.httpClient.info("doRequest ERROR: Base URL is nil")
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

        if type == .mjpegStream {
            request.setValue("multipart/x-mixed-replace", forHTTPHeaderField: "Accept")
        }

        if cacheingPolicy != .useProtocolCachePolicy {
            request.cachePolicy = cacheingPolicy
        }

        let (result, response): (T, URLResponse) = try await performRequest(request: request, type: type)
        if let response = response as? HTTPURLResponse {
            if (400 ... 599).contains(response.statusCode) {
                Logger.httpClient.error("HTTP error from URL \(url.absoluteString) : \(response.statusCode)")
                throw HTTPClientError.httpError(response.statusCode)
            }
            Logger.httpClient.info("Response from URL \(url.absoluteString) : \(response.statusCode)")
            return (result, response)
        }
        fatalError()
    }

    private func performRequest<T>(request: URLRequest, type: SessionType = .data) async throws -> (T, URLResponse) {
        var request = request

        let username = connectionConfiguration.username
        let password = connectionConfiguration.password
        let alwaysSendBasicAuth = connectionConfiguration.alwaysSendBasicAuth

        if connectionConfiguration.isCloudConnection || alwaysSendBasicAuth, !username.isEmpty, !password.isEmpty {
            request.setValue(basicAuthHeader(username: username, password: password), forHTTPHeaderField: "Authorization")
        }

        switch type {
        case .download:
            return try await session.download(for: request) as! (T, URLResponse)
        case .data:
            return try await session.data(for: request) as! (T, URLResponse)
        case .bytes:
            return try await session.bytes(for: request, delegate: nil) as! (T, URLResponse)
        case .mjpegStream:
            return try await session.data(for: request) as! (T, URLResponse)
        }
    }
}

public extension Notification.Name {
    static let evaluateServerTrust = Notification.Name("evaluateServerTrust")
    static let evaluateCertificateMismatch = Notification.Name("evaluateCertificateMismatch")
    static let acceptedServerCertificatesChanged = Notification.Name("acceptedServerCertificatesChanged")
}
