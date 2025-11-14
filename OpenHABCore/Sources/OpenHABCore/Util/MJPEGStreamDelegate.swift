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

// MARK: - MJPEGFrame for modelling data

public struct MJPEGFrame: Sendable {
    public let jpeg: Data
    public let headers: [String: String]
    public let receivedAt: Date
}

// MARK: - MJPEG Options

public struct MJPEGOptions: Sendable {
    /// Maximum size per frame; 0 = unlimited.
    public var maxPartBytes: Int
    /// Minimum time between yielded frames; 0 = yield all.
    public var minimumFrameInterval: TimeInterval

    public init(maxPartBytes: Int = 10 * 1024 * 1024,
                minimumFrameInterval: TimeInterval = 0) {
        self.maxPartBytes = maxPartBytes
        self.minimumFrameInterval = minimumFrameInterval
    }
}

// MARK: - Incremental multipart parser (tolerant)

private struct MultipartParser {
    struct Part {
        var headers: [String: String] = [:]
        var body = Data()
    }

    private enum State {
        case seekingBoundary
        case readingHeaders
        case readingBody
        case finished
    }

    private let boundary: Data // "--" + token
    private let options: MJPEGOptions

    private let crlf = Data([13, 10]) // \r\n
    private let lf = Data([10])
    private let doubleCRLF = Data([13, 10, 13, 10])
    private let doubleLF = Data([10, 10])

    private var state: State = .seekingBoundary
    private var buffer = Data()
    private var currentPart = Part()
    private let maxPartBytes: Int

    init(boundaryToken: String, options: MJPEGOptions) {
        boundary = Data(("--" + boundaryToken).utf8)
        self.options = options
        maxPartBytes = options.maxPartBytes
    }

    mutating func feed(_ data: Data) throws -> [Part] {
        guard !data.isEmpty, state != .finished else { return [] }
        buffer.append(data)
        var output: [Part] = []

        outer: while true {
            switch state {
            case .seekingBoundary:
                guard let boundaryRange = findBoundary(in: buffer) else {
                    // Keep only a tail big enough to contain a split boundary
                    let keep = boundary.count + 4
                    if buffer.count > keep {
                        buffer = buffer.suffix(keep)
                    }
                    break outer
                }
                let after = consumeBoundaryLine(start: boundaryRange.lowerBound)
                buffer.removeSubrange(..<after)
                currentPart = Part()
                state = .readingHeaders

            case .readingHeaders:
                guard let headerTerminator = findHeaderTerminator(in: buffer) else {
                    // Need more bytes; keep a reasonable header tail
                    if buffer.count > 4096 {
                        buffer = buffer.suffix(4096)
                    }
                    break outer
                }
                let headerData = buffer[..<headerTerminator.lowerBound]
                currentPart.headers = parseHeaders(headerData)
                buffer.removeSubrange(..<headerTerminator.upperBound)
                currentPart.body.removeAll(keepingCapacity: true)
                state = .readingBody

            case .readingBody:
                guard let boundaryRange = findBoundary(in: buffer) else {
                    // No boundary yet: append all but tail to body
                    let keep = boundary.count + 4
                    if buffer.count > keep {
                        let chunk = buffer[..<(buffer.count - keep)]
                        try appendToBody(chunk)
                        buffer = buffer.suffix(keep)
                    }
                    break outer
                }

                // Body ends at boundary start, minus optional CRLF
                var endIndex = boundaryRange.lowerBound
                if endIndex >= 2, buffer[endIndex - 2 ..< endIndex] == crlf {
                    endIndex -= 2
                } else if endIndex >= 1, buffer[endIndex - 1 ..< endIndex] == lf {
                    endIndex -= 1
                }

                let bodySlice = buffer[..<endIndex]
                try appendToBody(bodySlice)

                output.append(currentPart)
                currentPart = Part()
                let after = consumeBoundaryLine(start: boundaryRange.lowerBound)
                buffer.removeSubrange(..<after)
                // If consumeBoundaryLine set state to .finished, the next loop iteration will bail.

            case .finished:
                break outer
            }
        }

        return output
    }

    mutating func finish() {
        buffer.removeAll(keepingCapacity: false)
        state = .finished
    }

    // MARK: - Helpers

    private mutating func appendToBody(_ data: Data) throws {
        guard !data.isEmpty else { return }
        currentPart.body.append(data)
        if maxPartBytes > 0, currentPart.body.count > maxPartBytes {
            throw URLError(.dataLengthExceedsMaximum)
        }
    }

    private func findHeaderTerminator(in data: Data) -> Range<Data.Index>? {
        if let r = data.range(of: doubleCRLF) {
            return r
        }
        return data.range(of: doubleLF) // tolerate LF-only
    }

    private func parseHeaders(_ data: Data) -> [String: String] {
        guard let string = String(bytes: data, encoding: .utf8) else {
            // Data not valid UTF-8 → treat as no headers
            return [:] // or however you want to handle this
        }
        var result: [String: String] = [:]
        for rawLine in string.split(whereSeparator: \.isNewline) {
            guard let idx = rawLine.firstIndex(of: ":") else { continue }
            let name = rawLine[..<idx].trimmingCharacters(in: .whitespaces)
            let value = rawLine[rawLine.index(after: idx)...].trimmingCharacters(in: .whitespaces)
            result[name] = value
        }
        return result
    }

    private func findBoundary(in data: Data) -> Range<Data.Index>? {
        // Accept boundary at start, or after CRLF.
        if let r = data.range(of: crlf + boundary) {
            // Return range of the boundary itself (not including CRLF)
            let start = data.index(r.lowerBound, offsetBy: crlf.count)
            let end = r.upperBound
            return start ..< end
        }
        if let r = data.range(of: boundary) {
            return r
        }
        return nil
    }

    private mutating func consumeBoundaryLine(start: Data.Index) -> Data.Index {
        // start points at first "-" of "--boundary"
        var i = start
        i = buffer.index(i, offsetBy: boundary.count)

        var isClosing = false

        // Optional closing marker "--"
        let dashDash = Data("--".utf8)
        if i < buffer.endIndex, buffer[i...].starts(with: dashDash) {
            isClosing = true
            i = buffer.index(i, offsetBy: dashDash.count)
        }

        // Optional newline after boundary line
        if i < buffer.endIndex {
            if buffer[i...].starts(with: crlf) {
                i = buffer.index(i, offsetBy: crlf.count)
            } else if buffer[i...].starts(with: lf) {
                i = buffer.index(i, offsetBy: lf.count)
            }
        }

        if isClosing {
            state = .finished
        }

        return i
    }
}

final class StreamBridge: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let continuation: AsyncThrowingStream<Data, any Error>.Continuation
    private var isFinished = false

    init(_ continuation: AsyncThrowingStream<Data, any Error>.Continuation) {
        self.continuation = continuation
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(.allow) // <- REQUIRED
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        continuation.yield(data)
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: (any Error)?) {
        guard !isFinished else { return }
        isFinished = true

        if let error {
            continuation.finish(throwing: error)
        } else {
            continuation.finish()
        }
    }
}

// Small box so we can safely capture session/task in a @Sendable closure
final class SessionBox: @unchecked Sendable {
    let session: URLSession
    let task: URLSessionDataTask
    init(session: URLSession, task: URLSessionDataTask) {
        self.session = session
        self.task = task
    }
}

final class MJPEGStreamDelegate: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private let options: MJPEGOptions
    private let continuation: AsyncThrowingStream<MJPEGFrame, any Error>.Continuation
    private let connectionConfiguration: ConnectionConfiguration

    private var parser: MultipartParser?
    private var lastYield = Date(timeIntervalSince1970: 0)
    private var finished = false
    private var initialResponseReceived = false
    private var currentFrameData = Data()
    private var expectingJPEGResponse = false

    init(options: MJPEGOptions,
         continuation: AsyncThrowingStream<MJPEGFrame, any Error>.Continuation,
         connectionConfiguration: ConnectionConfiguration) {
        self.options = options
        self.continuation = continuation
        self.connectionConfiguration = connectionConfiguration
    }

    // MARK: - Helpers

    private static func extractBoundary(from contentType: String) -> String? {
        // e.g. "multipart/x-mixed-replace; boundary=--myBoundary"
        for part in contentType.split(separator: ";") {
            let trim = part.trimmingCharacters(in: .whitespaces)
            if trim.lowercased().hasPrefix("boundary=") {
                return String(trim.dropFirst("boundary=".count))
            }
        }
        return nil
    }

    fileprivate static func normalizeBoundary(_ raw: String) -> String {
        var token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.hasPrefix("\""), token.hasSuffix("\""), token.count >= 2 {
            token = String(token.dropFirst().dropLast())
        }
        if token.hasPrefix("--") {
            token.removeFirst(2)
        }
        return token
    }

    // MARK: - URLSessionDataDelegate

    // Response: detect boundary and create parser
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse) async -> URLSession.ResponseDisposition {
        Logger.videoProcessing.debug("MJPEG: Response received: \(response)")

        // If we've already processed the initial response, handle subsequent responses
        if initialResponseReceived {
            Logger.videoProcessing.debug("MJPEG: Subsequent response received, allowing...")

            // If we have accumulated data from a previous frame, yield it now
            if expectingJPEGResponse, !currentFrameData.isEmpty {
                // swiftformat:disable:next redundantSelf
                Logger.videoProcessing.debug("MJPEG: Processing previous JPEG frame, size: \(self.currentFrameData.count) bytes")
                yieldFrameIfAppropriate(currentFrameData)
            }

            // Check if this is a JPEG response (individual frame)
            if let http = response as? HTTPURLResponse,
               let contentType = http.value(forHTTPHeaderField: "Content-Type")?.lowercased(),
               contentType.contains("image/jpeg") {
                Logger.videoProcessing.debug("MJPEG: Detected individual JPEG frame response")
                expectingJPEGResponse = true
                currentFrameData = Data()
            }

            return .allow
        }

        guard let http = response as? HTTPURLResponse else {
            Logger.videoProcessing.debug("MJPEG: Response is not HTTPURLResponse: \(response)")
            finished = true
            continuation.finish(throwing: URLError(.badServerResponse))
            return .cancel
        }

        Logger.videoProcessing.debug("MJPEG: HTTP Status: \(http.statusCode)")
        Logger.videoProcessing.debug("MJPEG: HTTP Headers: \(http.allHeaderFields)")

        guard let contentTypeRaw = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() else {
            Logger.videoProcessing.debug("MJPEG: Missing Content-Type header")
            finished = true
            continuation.finish(throwing: URLError(.badServerResponse))
            return .cancel
        }

        print("MJPEG: Content-Type: \(contentTypeRaw)")

        guard contentTypeRaw.contains("multipart/x-mixed-replace") else {
            Logger.videoProcessing.debug("MJPEG: Content-Type does not contain 'multipart/x-mixed-replace'")
            finished = true
            continuation.finish(throwing: URLError(.badServerResponse))
            return .cancel
        }

        guard let boundaryToken = Self.extractBoundary(from: contentTypeRaw) else {
            Logger.videoProcessing.debug("MJPEG: Failed to extract boundary token from Content-Type")
            finished = true
            continuation.finish(throwing: URLError(.badServerResponse))
            return .cancel
        }

        Logger.videoProcessing.debug("MJPEG: Boundary token: \(boundaryToken)")
        let norm = Self.normalizeBoundary(boundaryToken)
        Logger.videoProcessing.debug("MJPEG: Normalized boundary: \(norm)")
        parser = MultipartParser(boundaryToken: norm, options: options)
        initialResponseReceived = true
        return .allow
    }

    // Data: feed into parser, yield frames
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        Logger.videoProcessing.debug("MJPEG: didReceive data, size \(data.count) bytes")

        guard !finished else { return }

        // Handle individual JPEG response
        if expectingJPEGResponse {
            Logger.videoProcessing.debug("MJPEG: Accumulating JPEG frame data")
            currentFrameData.append(data)
            return
        }

        // Handle multipart stream
        guard var parser else { return }

        do {
            let parts = try parser.feed(data)
            self.parser = parser // write back mutated parser

            for part in parts {
                guard !finished else { return }

                if options.minimumFrameInterval > 0 {
                    let now = Date()
                    if now.timeIntervalSince(lastYield) < options.minimumFrameInterval { continue }
                    lastYield = now
                } else {
                    lastYield = Date()
                }

                let frame = MJPEGFrame(
                    jpeg: part.body,
                    headers: part.headers,
                    receivedAt: Date()
                )
                continuation.yield(frame)
            }
        } catch {
            finished = true
            continuation.finish(throwing: error)
            dataTask.cancel()
            session.invalidateAndCancel()
        }
    }

    // MARK: - URLSessionTaskDelegate

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        // Handle completion of individual JPEG response
        if expectingJPEGResponse, !currentFrameData.isEmpty {
            // swiftformat:disable:next redundantSelf
            Logger.videoProcessing.debug("MJPEG: Processing individual JPEG frame, sizself.e: \(self.currentFrameData.count) bytes")
            yieldFrameIfAppropriate(currentFrameData)
            expectingJPEGResponse = false
            currentFrameData = Data()
            return
        }

        guard !finished else { return }
        finished = true

        if let error, (error as NSError).code != NSURLErrorCancelled {
            continuation.finish(throwing: error)
        } else {
            continuation.finish()
        }
    }

    private func yieldFrame(_ jpegData: Data) {
        let frame = MJPEGFrame(
            jpeg: jpegData,
            headers: [:], // No multipart headers for individual responses
            receivedAt: Date()
        )
        continuation.yield(frame)
        print("MJPEG: Successfully yielded JPEG frame")
    }

    private func yieldFrameIfAppropriate(_ jpegData: Data) {
        // Apply frame rate limiting
        if options.minimumFrameInterval > 0 {
            let now = Date()
            if now.timeIntervalSince(lastYield) >= options.minimumFrameInterval {
                lastYield = now
                yieldFrame(jpegData)
            }
        } else {
            lastYield = Date()
            yieldFrame(jpegData)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        Logger.videoProcessing.debug("MJPEG: Received authentication challenge: \(challenge.protectionSpace.authenticationMethod)")
        Logger.videoProcessing.debug("MJPEG: Host: \(challenge.protectionSpace.host)")
        // swiftformat:disable:next redundantSelf
        Logger.videoProcessing.debug("MJPEG: Username: \(self.connectionConfiguration.username)")

        // Handle authentication challenge for MJPEG streams
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic {
            Logger.videoProcessing.debug("MJPEG: Handling Basic Auth challenge")
            let credential = URLCredential(user: connectionConfiguration.username, password: connectionConfiguration.password, persistence: .forSession)
            completionHandler(.useCredential, credential)
        } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            // swiftformat:disable:next redundantSelf
            Logger.videoProcessing.debug("MJPEG: Handling Server Trust challenge, ignoreSSL: \(self.connectionConfiguration.ignoreSSL)")
            // Handle SSL/TLS certificates
            if connectionConfiguration.ignoreSSL {
                completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        } else {
            Logger.videoProcessing.debug("MJPEG: Unhandled challenge method: \(challenge.protectionSpace.authenticationMethod)")
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
