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

import OpenHABCore
import os.log
import UIKit

@MainActor
final class MJPEGPlayer {
    private var activeTask: Task<Void, Never>?
    private let imageView: UIImageView

    var onFirstFrame: ((CGFloat) -> Void)?
    var onError: ((any Error) -> Void)?

    init(imageView: UIImageView) {
        self.imageView = imageView
    }

    func play(url: URL) {
        stop()

        activeTask = Task { [weak self] in
            guard let self else { return }
            do {
                guard let config = MainActorNetworkTracker.shared.activeConnection?.configuration else {
                    throw HTTPClientError.noConfiguration
                }

                let client = HTTPClient(streamingWith: .ephemeral, connectionConfiguration: config)
                let frameStream = try await client.mjpegFrames(url: url)

                var isFirstFrame = true
                for try await frame in frameStream {
                    guard !Task.isCancelled else { break }

                    if let image = UIImage(data: frame.jpeg) {
                        imageView.image = image

                        if isFirstFrame {
                            isFirstFrame = false
                            let aspectRatio = image.size.width / image.size.height
                            onFirstFrame?(aspectRatio)
                        }
                    }
                }
            } catch is CancellationError {
                // Task was cancelled, ignore
            } catch {
                onError?(error)
            }
        }
    }

    func stop() {
        activeTask?.cancel()
        activeTask = nil
        imageView.image = nil
    }
}
