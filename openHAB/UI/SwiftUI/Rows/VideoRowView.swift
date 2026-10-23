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

import AVKit
import CommonUI
import OpenHABCore
import os.log
import SwiftUI
import UIKit

private enum VideoEncoding: String {
    case hls
    case mjpeg
}

private struct VideoRowConfig {
    let input: MediaRowInput
}

@MainActor
private func makeVideoRowContent(_ config: VideoRowConfig) -> VideoRowContent {
    VideoRowContent(input: config.input)
}

private struct VideoRowContent: View {
    /// Placeholder until the stream reports its real size; the sitemap carries no size information.
    private static let defaultAspectRatio: CGFloat = 16.0 / 9.0

    let input: MediaRowInput
    @State private var player: AVPlayer?
    @State private var mjpegPlayer: SimpleMJPEGPlayer?
    @State private var mjpegImage: UIImage?
    @State private var aspectRatio = Self.defaultAspectRatio
    @State private var isLoading = false
    @State private var currentStreamUrl: URL?
    @State private var playerObservers: [NSKeyValueObservation] = []

    private let logger = Logger(subsystem: "org.openhab", category: "VideoRowView")

    private var videoURL: URL? {
        guard !input.url.isEmpty else { return nil }
        return URL(string: input.url)
    }

    private var isMJPEG: Bool {
        input.encoding.lowercased() == VideoEncoding.mjpeg.rawValue
    }

    var body: some View {
        let displayState = input.displayState
        VStack(alignment: .leading, spacing: 8) {
            if !displayState.labelText.isEmpty, input.labelSourceRawValue == OpenHABWidget.LabelSource.sitemapDefinition.rawValue {
                let labelText = displayState.labelText
                Text(labelText)
                    .ohTextToken(.rowLabel)
                    .foregroundStyle(input.labelColor.isEmpty ? .primary : Color(fromString: input.labelColor))
            }

            if let videoURL {
                ZStack {
                    if isMJPEG {
                        if let mjpegImage {
                            Image(uiImage: mjpegImage)
                                .resizable()
                                .aspectRatio(aspectRatio, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .clipShape(.rect(cornerRadius: 8))
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(aspectRatio, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .clipShape(.rect(cornerRadius: 8))
                        }
                    } else {
                        // HLS/other video formats using VideoPlayer
                        VideoPlayer(player: player)
                            .aspectRatio(aspectRatio, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .clipShape(.rect(cornerRadius: 8))
                    }

                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
                .frame(maxWidth: .infinity)
                .onAppear {
                    setupVideo(url: videoURL)
                }
                .onDisappear {
                    cleanup()
                }
                .onChange(of: input.url) { _, newValue in
                    if !newValue.isEmpty, let newURL = URL(string: newValue) {
                        setupVideo(url: newURL)
                    } else {
                        cleanup()
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .overlay(
                        Text("No Video URL")
                            .foregroundStyle(.secondary)
                    )
                    .clipShape(.rect(cornerRadius: 8))
            }

            if let labelValue = displayState.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .ohTextToken(.rowValueCompact)
                    .foregroundStyle(input.valueColor.isEmpty ? .secondary : Color(fromString: input.valueColor))
            }
        }
    }

    @MainActor
    private func setupVideo(url: URL) {
        // Avoid redundant setup if URL hasn't changed
        if currentStreamUrl?.absoluteString == url.absoluteString {
            return
        }

        // Clean up previous setup
        cleanup()
        currentStreamUrl = url
        isLoading = true

        if isMJPEG {
            setupMJPEG(url: url)
        } else {
            setupHLS(url: url)
        }
    }

    @MainActor
    private func setupMJPEG(url: URL) {
        mjpegPlayer = VideoStreamManager.shared.getOrCreateStream(
            for: url,
            // Derive the ratio from every frame: a shared stream's first frame may predate this
            // subscriber, and cameras may change resolution mid-stream
            onFrame: { image in
                mjpegImage = image
                updateAspectRatio(image.size)
                if isLoading {
                    isLoading = false
                }
            },
            onError: { [logger] error in
                logger.debug("MJPEG stream error: \(error.localizedDescription)")
                isLoading = false
            }
        )
    }

    private func setupHLS(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        // Observe player readiness
        let statusObserver = playerItem.observe(\.status, options: [.new, .old]) { item, _ in
            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    isLoading = false
                    // Auto-play when ready
                    player?.play()
                case .failed:
                    isLoading = false
                    logger.debug("HLS player failed: \(item.error?.localizedDescription ?? "Unknown error")")
                default:
                    break
                }
            }
        }
        // HLS often reports presentationSize as zero at readyToPlay and fills it in later
        let sizeObserver = playerItem.observe(\.presentationSize, options: [.initial, .new]) { item, _ in
            Task { @MainActor in
                updateAspectRatio(item.presentationSize)
            }
        }
        playerObservers = [statusObserver, sizeObserver]
    }

    private func updateAspectRatio(_ size: CGSize) {
        guard let newAspectRatio = size.videoAspectRatio, newAspectRatio != aspectRatio else { return }
        aspectRatio = newAspectRatio
    }

    private func cleanup() {
        // Clean up HLS observers
        playerObservers = []

        // Release MJPEG stream
        if let currentStreamUrl, isMJPEG {
            VideoStreamManager.shared.releaseStream(for: currentStreamUrl)
        }

        // Clean up HLS player
        player?.pause()
        player = nil

        mjpegPlayer = nil
        mjpegImage = nil
        currentStreamUrl = nil
        aspectRatio = Self.defaultAspectRatio
        isLoading = false
    }
}

struct VideoRowView: View {
    let input: MediaRowInput

    var body: some View {
        makeVideoRowContent(
            VideoRowConfig(
                input: input
            )
        )
    }
}

extension CGSize {
    /// Width-to-height ratio, or `nil` while the size is still unknown (zero or degenerate).
    var videoAspectRatio: CGFloat? {
        guard width > 0, height > 0 else { return nil }
        return width / height
    }
}
