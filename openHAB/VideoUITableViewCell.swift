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

import AVFoundation
import AVKit
import OpenHABCore
import os.log

enum VideoEncoding: String {
    case hls, mjpeg
}

class VideoUITableViewCell: GenericUITableViewCell, NoIconDisplayableCell {
    private var activityIndicator: UIActivityIndicatorView = if #available(iOS 13.0, *) {
        .init(style: .medium)
    } else {
        .init(style: .gray)
    }

    var didLoad: (() -> Void)?

    private var url: URL? {
        didSet {
            guard oldValue?.absoluteString != url?.absoluteString else { return }
            prepareToPlay()
        }
    }

    private var playerView: PlayerView!
    private var mainImageView: UIImageView!
    private var playerObserver: NSKeyValueObservation?
    private var aspectRatioConstraint: NSLayoutConstraint?
    private var mjpegPlayer: SimpleMJPEGPlayer?
    private var currentAspectRatio: CGFloat?
    private var currentStreamUrl: URL?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        activityIndicator.hidesWhenStopped = true
        playerView = PlayerView()
        playerView.isHidden = true // Start hidden, will be shown when needed
        contentView.addSubview(playerView)
        mainImageView = UIImageView()
        mainImageView.contentMode = .scaleAspectFit
        mainImageView.isHidden = true // Start hidden, will be shown when needed
        contentView.addSubview(mainImageView)
        contentView.addSubview(activityIndicator)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false // enable autolayout
        playerView.translatesAutoresizingMaskIntoConstraints = false // enable autolayout
        playerView.contentMode = .scaleAspectFit

        let marginGuide = contentView // contentView.layoutMarginsGuide if more margin would be appreciated
        NSLayoutConstraint.activate([
            playerView.leftAnchor.constraint(equalTo: marginGuide.leftAnchor),
            playerView.rightAnchor.constraint(equalTo: marginGuide.rightAnchor),
            playerView.topAnchor.constraint(equalTo: marginGuide.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: marginGuide.bottomAnchor)
        ])

        mainImageView.translatesAutoresizingMaskIntoConstraints = false // enable autolayout
        NSLayoutConstraint.activate([
            mainImageView.leftAnchor.constraint(equalTo: marginGuide.leftAnchor),
            mainImageView.rightAnchor.constraint(equalTo: marginGuide.rightAnchor),
            mainImageView.topAnchor.constraint(equalTo: marginGuide.topAnchor),
            mainImageView.bottomAnchor.constraint(equalTo: marginGuide.bottomAnchor)
        ])

        let bottomSpacingConstraint = activityIndicator.bottomAnchor.constraint(greaterThanOrEqualTo: marginGuide.bottomAnchor, constant: 15)
        bottomSpacingConstraint.priority = UILayoutPriority.defaultHigh
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: marginGuide.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: marginGuide.centerYAnchor),
            activityIndicator.topAnchor.constraint(greaterThanOrEqualTo: marginGuide.topAnchor, constant: 15),
            bottomSpacingConstraint
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(stopPlayback), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)

        if newSuperview == nil {
            stopPlayback()
            // Release stream reference when cell is removed
            if let currentStreamUrl {
                VideoStreamManager.shared.releaseStream(for: currentStreamUrl)
                self.currentStreamUrl = nil
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        // Clean up any previous state
        stopPlayback()
        if let currentStreamUrl {
            VideoStreamManager.shared.releaseStream(for: currentStreamUrl)
            self.currentStreamUrl = nil
        }
        mjpegPlayer = nil
        currentAspectRatio = nil

        // Reset view states
        mainImageView.image = nil
        mainImageView.isHidden = true
        playerView.isHidden = true
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true

        // Remove aspect ratio constraint
        if let aspectRatioConstraint {
            aspectRatioConstraint.isActive = false
            self.aspectRatioConstraint = nil
        }
    }

    override func displayWidget() {
        let newUrl = URL(string: widget.url)

        // Handle MJPEG streams with VideoStreamManager
        if widget.encoding.lowercased() == VideoEncoding.mjpeg.rawValue {
            // Stop any HLS playback and hide player view
            playerView?.playerLayer.player = nil
            playerView.isHidden = true
            mainImageView.isHidden = false

            // Only process if URL has changed, similar to HLS handling
            if currentStreamUrl?.absoluteString != newUrl?.absoluteString {
                // Release previous stream if URL changed
                if let currentStreamUrl {
                    VideoStreamManager.shared.releaseStream(for: currentStreamUrl)
                }

                if let newUrl {
                    currentStreamUrl = newUrl
                    mjpegPlayer = VideoStreamManager.shared.getOrCreateStream(
                        for: newUrl,
                        imageView: mainImageView,
                        onFirstFrame: { [weak self] aspectRatio in
                            guard let self else { return }
                            activityIndicator.isHidden = true
                            if currentAspectRatio != aspectRatio {
                                updateAspectRatio(forView: mainImageView, aspectRatio: aspectRatio)
                                currentAspectRatio = aspectRatio
                                didLoad?()
                            }
                        },
                        onError: { [weak self] error in
                            guard let self else { return }
                            Logger.widgets.error("Failed to start MJPEG stream: \(error.localizedDescription)")
                            activityIndicator.isHidden = true
                            activityIndicator.stopAnimating()
                        }
                    )

                    // Set initial aspect ratio for MJPEG
                    updateAspectRatio(forView: mainImageView, aspectRatio: 16.0 / 9.0)

                    // Start activity indicator
                    bringSubviewToFront(activityIndicator)
                    activityIndicator.isHidden = false
                    activityIndicator.startAnimating()
                    bringSubviewToFront(mainImageView)
                } else {
                    currentStreamUrl = nil
                }
            }
        } else {
            // Handle HLS and other video formats
            // Clear any MJPEG stream and hide image view
            if let currentStreamUrl {
                VideoStreamManager.shared.releaseStream(for: currentStreamUrl)
                self.currentStreamUrl = nil
            }
            mjpegPlayer = nil
            mainImageView.image = nil
            mainImageView.isHidden = true
            playerView.isHidden = false

            if url?.absoluteString != newUrl?.absoluteString {
                url = newUrl
            }
            let targetView = playerView!
            updateAspectRatio(forView: targetView, aspectRatio: 16.0 / 9.0)
        }
    }

    func play() {
        switch widget.encoding.lowercased() {
        case VideoEncoding.mjpeg.rawValue:
            // MJPEG streams are already managed by VideoStreamManager in displayWidget()
            break
        default:
            playerView.player?.play()
        }
    }

    private func prepareToPlay() {
        bringSubviewToFront(activityIndicator)
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
        stopPlayback(andResetUrl: false)

        guard let url else {
            stopPlayback()
            return
        }

        if widget.encoding.lowercased() != VideoEncoding.mjpeg.rawValue {
            Logger.videoProcessing.info("Loading HLS video from: \(url.absoluteString)")
            bringSubviewToFront(playerView)
            let playerItem = AVPlayerItem(asset: AVAsset(url: url))
            playerObserver = playerItem.observe(\.status, options: [.new, .old]) { [weak self] playerItem, _ in
                guard let self else { return }

                switch playerItem.status {
                case .failed:
                    Logger.widgets.debug("Failed to load video with URL: \(url.absoluteString)")
                    Task { @MainActor in
                        self.url = nil
                    }
                case .readyToPlay:
                    Logger.widgets.debug("Loaded video with URL: \(url.absoluteString)")
                default: return
                }
                Task { @MainActor in
                    self.activityIndicator.isHidden = true
                    if playerItem.status == .readyToPlay, playerItem.presentationSize != .zero {
                        let aspectRatio = playerItem.presentationSize.width / playerItem.presentationSize.height
                        self.updateAspectRatio(forView: self.playerView, aspectRatio: aspectRatio)
                        self.didLoad?()
                    }
                }
            }
            playerView?.playerLayer.player = AVPlayer(playerItem: playerItem)
        }
    }

    // Add or update the aspect ratio constraint for the given view
    private func updateAspectRatio(forView view: UIView, aspectRatio: CGFloat) {
        // Remove the old aspect ratio constraint if it exists
        if let oldConstraint = aspectRatioConstraint {
            oldConstraint.isActive = false
            aspectRatioConstraint = nil
        }

        // Force layout to process constraint removal before adding new one
        view.layoutIfNeeded()

        // Add a new aspect ratio constraint
        let constraint = view.widthAnchor.constraint(equalTo: view.heightAnchor, multiplier: aspectRatio)
        constraint.priority = UILayoutPriority(rawValue: 998) // Lower than UIImageView's 999
        constraint.isActive = true
        aspectRatioConstraint = constraint
    }

    @objc
    private func stopPlayback(andResetUrl reset: Bool = true) {
        // For MJPEG streams, don't stop the shared stream - just clear our reference
        if widget?.encoding.lowercased() == VideoEncoding.mjpeg.rawValue {
            mjpegPlayer = nil
        } else {
            // For HLS and other formats, stop as usual
            if reset {
                url = nil
            }
            playerObserver = nil
            playerView?.playerLayer.player = nil
        }
        currentAspectRatio = nil
    }
}
