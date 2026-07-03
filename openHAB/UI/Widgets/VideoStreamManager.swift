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

import Foundation
import OpenHABCore
import os.log
import UIKit

@MainActor
final class VideoStreamManager {
    static let shared = VideoStreamManager()

    private var activeStreams: [String: SimpleMJPEGPlayer] = [:]
    private var streamReferenceCounts: [String: Int] = [:]

    private init() {}

    func getOrCreateStream(
        for url: URL,
        onFrame: @escaping @MainActor (UIImage) -> Void,
        onFirstFrame: ((CGFloat) -> Void)?,
        onError: ((any Error) -> Void)?
    ) -> SimpleMJPEGPlayer {
        let key = url.absoluteString

        if let existingPlayer = activeStreams[key] {
            existingPlayer.updateCallbacks(onFrame: onFrame, onFirstFrame: onFirstFrame, onError: onError)
            streamReferenceCounts[key] = (streamReferenceCounts[key] ?? 0) + 1
            // swiftformat:disable:next redundantSelf
            Logger.widgets.debug("Reusing existing stream for URL: \(key), refs: \(self.streamReferenceCounts[key] ?? 0)")
            return existingPlayer
        }

        let player = SimpleMJPEGPlayer()
        player.onFrame = onFrame
        player.onFirstFrame = onFirstFrame
        player.onError = onError

        activeStreams[key] = player
        streamReferenceCounts[key] = 1

        player.play(url: url)

        Logger.widgets.debug("Created new stream for URL: \(key)")
        return player
    }

    func releaseStream(for url: URL) {
        let key = url.absoluteString

        guard let currentCount = streamReferenceCounts[key] else {
            Logger.widgets.warning("Attempted to release stream that wasn't tracked: \(key)")
            return
        }

        let newCount = currentCount - 1
        streamReferenceCounts[key] = newCount

        Logger.widgets.debug("Released stream reference for URL: \(key), remaining refs: \(newCount)")

        if newCount <= 0 {
            if let player = activeStreams[key] {
                player.stop()
                Logger.widgets.debug("Stopped and removed stream for URL: \(key)")
            }

            activeStreams.removeValue(forKey: key)
            streamReferenceCounts.removeValue(forKey: key)
        }
    }

    func cleanupUnusedStreams() {
        let keysToRemove = streamReferenceCounts.compactMap { key, count in
            count < 1 ? key : nil
        }

        for key in keysToRemove {
            if let player = activeStreams[key] {
                player.stop()
            }
            activeStreams.removeValue(forKey: key)
            streamReferenceCounts.removeValue(forKey: key)
            Logger.widgets.debug("Cleaned up unused stream: \(key)")
        }
    }
}
