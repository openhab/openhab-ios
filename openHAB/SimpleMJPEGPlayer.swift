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
import OpenHABCore
import os.log
import UIKit

// MARK: - Dedicated URLSession Delegate

// final class SimpleMJPEGStreamDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
//    private var imageData = Data()
//    private var isFirstFrame = true
//    private let onFrame: @MainActor (UIImage, Bool) -> Void
//    private let onError: @MainActor (any Error) -> Void
//
//    init(onFrame: @escaping @MainActor (UIImage, Bool) -> Void,
//         onError: @escaping @MainActor (any Error) -> Void) {
//        self.onFrame = onFrame
//        self.onError = onError
//        super.init()
//    }
//
//    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
//        // Simple JPEG frame detection: look for JPEG header (0xFF, 0xD8)
//        let jpegHeader = Data([0xFF, 0xD8])
//
//        if data.starts(with: jpegHeader) {
//            // New frame starts - process previous frame if we have data
//            if !imageData.isEmpty, let image = UIImage(data: imageData) {
//                let isFirst = isFirstFrame
//                if isFirstFrame { isFirstFrame = false }
//
//                Task { @MainActor in
//                    self.onFrame(image, isFirst)
//                }
//            }
//            // Start new frame
//            imageData = data
//        } else {
//            // Continue building current frame
//            imageData.append(data)
//        }
//    }
//
//    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didCompleteWithError error: Error?) {
//        if let error, (error as NSError).code != NSURLErrorCancelled {
//            Task { @MainActor in
//                self.onError(error)
//            }
//        }
//    }
//
//    func reset() {
//        imageData.removeAll()
//        isFirstFrame = true
//    }
// }

// MARK: - Main Actor Player

@MainActor
final class SimpleMJPEGPlayer {
    private var dataTask: URLSessionDataTask?
    private var session: URLSession?
    private var delegate: SimpleMJPEGStreamDelegate?
    private let imageView: UIImageView
    private var currentAspectRatio: CGFloat?

    var onFirstFrame: ((CGFloat) -> Void)?
    var onError: ((any Error) -> Void)?

    init(imageView: UIImageView) {
        self.imageView = imageView
    }

    func play(url: URL) {
        stop()

        guard let config = MainActorNetworkTracker.shared.activeConnection?.configuration else {
            onError?(HTTPClientError.noConfiguration)
            return
        }

        delegate = SimpleMJPEGStreamDelegate(
            connectionConfiguration: config,
            onFrame: { [weak self] image, isFirst in
                guard let self else { return }
                imageView.image = image

                if isFirst {
                    let aspectRatio = image.size.width / image.size.height
                    onFirstFrame?(aspectRatio)
                }
            },
            onError: { [weak self] error in
                guard let self else { return }
                onError?(error)
            }
        )

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = 0
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        session = URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: nil)

        var request = URLRequest(url: url)
        request.setValue("multipart/x-mixed-replace", forHTTPHeaderField: "Accept")

        // Add Basic Auth if available
        if !config.username.isEmpty, !config.password.isEmpty {
            let credentials = "\(config.username):\(config.password)"
            if let credentialsData = credentials.data(using: .utf8) {
                let base64Credentials = credentialsData.base64EncodedString()
                request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            }
        }

        dataTask = session?.dataTask(with: request)
        dataTask?.resume()
    }

    func stop() {
        dataTask?.cancel()
        dataTask = nil
        session?.invalidateAndCancel()
        session = nil
        delegate = nil
        imageView.image = nil
        currentAspectRatio = nil
    }
}
