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

@MainActor
final class SimpleMJPEGPlayer {
    private var streamTask: URLSessionDataTask?
    private var httpClient: HTTPClient?
    private var delegate: SimpleMJPEGStreamDelegate?
    private let imageView: UIImageView

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

        httpClient = HTTPClient(streamingWith: .ephemeral, connectionConfiguration: config, delegate: delegate)

        var request = URLRequest(url: url)
        request.setValue("multipart/x-mixed-replace", forHTTPHeaderField: "Accept")

        streamTask = httpClient?.session.dataTask(with: request)
        streamTask?.resume()
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        httpClient = nil
        delegate = nil
        imageView.image = nil
    }
}
