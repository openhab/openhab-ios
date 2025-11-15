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

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        activityIndicator.hidesWhenStopped = true
        playerView = PlayerView()
        contentView.addSubview(playerView)
        mainImageView = ScaleAspectFitImageView()
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

        setupMJPEGPlayer()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)

        if newSuperview == nil {
            stopPlayback()
        }
    }

    override func displayWidget() {
        url = URL(string: widget.url)

        // Set initial aspect ratio to prevent standard height display
        // Use 16:9 as default, will be updated when actual video dimensions are available
        if aspectRatioConstraint == nil {
            updateAspectRatio(forView: widget.encoding.lowercased() == VideoEncoding.mjpeg.rawValue ? mainImageView : playerView, aspectRatio: 16.0 / 9.0)
        }
    }

    func play() {
        switch widget.encoding.lowercased() {
        case VideoEncoding.mjpeg.rawValue:
            playMjpegStream()
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

    private func setupMJPEGPlayer() {
        mjpegPlayer = SimpleMJPEGPlayer(imageView: mainImageView)
        mjpegPlayer?.onFirstFrame = { [weak self] aspectRatio in
            guard let self else { return }
            activityIndicator.isHidden = true
            if currentAspectRatio != aspectRatio {
                updateAspectRatio(forView: mainImageView, aspectRatio: aspectRatio)
                currentAspectRatio = aspectRatio
                didLoad?()
            }
        }
        mjpegPlayer?.onError = { [weak self] error in
            guard let self else { return }
            Logger.widgets.error("Failed to start MJPEG stream: \(error.localizedDescription)")
            activityIndicator.isHidden = true
            activityIndicator.stopAnimating()
        }
    }

    private func playMjpegStream() {
        guard let url else {
            stopPlayback()
            return
        }

        bringSubviewToFront(mainImageView)
        mjpegPlayer?.play(url: url)
    }

    // Add or update the aspect ratio constraint for the given view
    private func updateAspectRatio(forView view: UIView, aspectRatio: CGFloat) {
        // Remove the old aspect ratio constraint if it exists
        if let oldConstraint = aspectRatioConstraint {
            view.removeConstraint(oldConstraint)
            aspectRatioConstraint = nil
        }
        // Add a new aspect ratio constraint
        let constraint = view.widthAnchor.constraint(equalTo: view.heightAnchor, multiplier: aspectRatio)
        constraint.priority = .required
        constraint.isActive = true
        aspectRatioConstraint = constraint
    }

    @objc
    private func stopPlayback(andResetUrl reset: Bool = true) {
        // Increment the stream token to invalidate any running MJPEG stream tasks
        if reset {
            url = nil
        }
        playerObserver = nil
        playerView?.playerLayer.player = nil
        mjpegPlayer?.stop()
        currentAspectRatio = nil
    }
}
