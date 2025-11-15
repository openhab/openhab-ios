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
import UIKit

/// This delegate is used on URLSession callbacks and isn't intended to cross concurrency domains.
/// We opt into @unchecked Sendable to silence the warning about mutable stored properties.
public final class SimpleMJPEGStreamDelegate: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private var imageData = Data()
    private var isFirstFrame = true
    private let onFrame: @MainActor (UIImage, Bool) -> Void
    private let onError: @MainActor (any Error) -> Void
    private let synchronizationQueue = DispatchQueue(label: "SimpleMJPEGStreamDelegate.sync", qos: .userInitiated)

    private let httpClientDelegate: HTTPClientDelegate
    private let connectionConfiguration: ConnectionConfiguration

    public init(connectionConfiguration: ConnectionConfiguration,
                onFrame: @escaping @MainActor (UIImage, Bool) -> Void,
                onError: @escaping @MainActor (any Error) -> Void) {
        self.onFrame = onFrame
        self.onError = onError
        self.connectionConfiguration = connectionConfiguration
        httpClientDelegate = HTTPClientDelegate(with: connectionConfiguration)
    }

    // MARK: - URLSessionDataDelegate

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Simple JPEG frame detection: look for JPEG header (0xFF, 0xD8)
        let jpegHeader = Data([0xFF, 0xD8])

//      The mutable state (imageData, isFirstFrame)  is accessed from URLSession delegate callbacks which may be called from different threads.
//      All delegate callbacks are confined to a single queue via the URLSession's delegateQueue parameter.

        synchronizationQueue.sync {
            if data.starts(with: jpegHeader) {
                // New frame starts - process previous frame if we have data
                if !imageData.isEmpty, let image = UIImage(data: imageData) {
                    let isFirst = isFirstFrame
                    if isFirstFrame { isFirstFrame = false }

                    Task { @MainActor in
                        self.onFrame(image, isFirst)
                    }
                }
                // Start new frame
                imageData = data
            } else {
                // Continue building current frame
                imageData.append(data)
            }
        }
    }

    // MARK: - URLSessionTaskDelegate

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if let error, (error as NSError).code != NSURLErrorCancelled {
            Task { @MainActor in
                self.onError(error)
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        Logger.videoProcessing.debug("MJPEG: Received authentication challenge: \(challenge.protectionSpace.authenticationMethod)")
        Logger.videoProcessing.debug("MJPEG: Host: \(challenge.protectionSpace.host)")

        // Delegate all authentication handling to HTTPClientDelegate
        return await httpClientDelegate.urlSession(session, task: task, didReceive: challenge)
    }
}

extension SimpleMJPEGStreamDelegate: URLSessionDelegate {
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await httpClientDelegate.urlSession(session, didReceive: challenge)
    }
}
