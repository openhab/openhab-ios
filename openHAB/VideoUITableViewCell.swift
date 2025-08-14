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
    private let logger = Logger(subsystem: "org.openhab", category: "VideoUITableViewCell")

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
    private var activeTask: Task<Void, Never>?
    private var session: URLSession!

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
                    logger.debug("Failed to load video with URL: \(url.absoluteString)")
                    Task { @MainActor in
                        self.url = nil
                    }
                case .readyToPlay:
                    logger.debug("Loaded video with URL: \(url.absoluteString)")
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

    private func playMjpegStream() {
        guard let url else {
            stopPlayback()
            return
        }

        // Cancel any existing task before starting a new one
        if let existingTask = activeTask {
            existingTask.cancel()
            activeTask = nil
        }

        bringSubviewToFront(mainImageView)

        activeTask = Task { [weak self] in
            guard let self else { return }

            // Check if task was cancelled before starting work
            guard !Task.isCancelled else {
                logger.debug("MJPEG stream task was cancelled before starting")
                return
            }

            do {
                guard let config = NetworkTracker.shared.activeConnection?.configuration else {
                    logger.warning("No openHAB configuration found.")
                    throw HTTPClientError.noConfiguration
                }
                logger.debug("Starting MJPEG stream for URL: \(url.absoluteString)")
                let client = HTTPClient(configuration: config)
                let (byteStream, response) = try await client.processStream(url: url)
                logger.debug("Successfully got MJPEG stream response: \(response)")
                await handleMJPEGStream(byteStream)
            } catch is CancellationError {
                logger.debug("MJPEG stream was cancelled during setup")
            } catch {
                logger.error("Failed to start MJPEG stream: \(error.localizedDescription)")
                await MainActor.run { [weak self] in
                    self?.activityIndicator.isHidden = true
                    self?.activityIndicator.stopAnimating()
                }
            }
        }
    }

    private func handleMJPEGStream(_ byteStream: URLSession.AsyncBytes) async {
        let streamImageInitialBytePattern = Data([255, 216])
        var imageData = Data()
        var isFirstFrame = true

        logger.debug("Starting to process MJPEG byte stream")

        do {
            for try await byte in byteStream {
                guard !Task.isCancelled else {
                    logger.debug("MJPEG stream task was cancelled")
                    return
                }

                imageData.append(byte)

                if imageData.count <= 50 {
                    logger.debug("Received bytes (\(imageData.count)): \(imageData.prefix(50).map { String(format: "%02x", $0) }.joined(separator: " "))")
                }

                if imageData.starts(with: streamImageInitialBytePattern), let image = UIImage(data: imageData) {
                    logger.debug("Successfully decoded MJPEG frame, size: \(image.size.width)x\(image.size.height)")

                    await MainActor.run { [weak self] in
                        guard let self else { return }

                        if isFirstFrame {
                            let aspectRatio = image.size.width / image.size.height
                            activityIndicator.isHidden = true
                            updateAspectRatio(forView: mainImageView, aspectRatio: aspectRatio)
                            isFirstFrame = false
                            didLoad?()
                        }
                        mainImageView?.image = image
                    }
                    imageData = Data()
                }
            }
        } catch is CancellationError {
            logger.debug("MJPEG stream was cancelled")
        } catch {
            logger.error("Failed to process MJPEG stream: \(error.localizedDescription)")
            await MainActor.run { [weak self] in
                self?.activityIndicator.isHidden = true
                self?.activityIndicator.stopAnimating()
            }
        }
    }

    private func updateAspectRatio(forView view: UIView?, aspectRatio: CGFloat) {
        guard let view else { return }

        if let constraint = aspectRatioConstraint {
            removeConstraint(constraint)
        }
        aspectRatioConstraint = nil

        let constraint = NSLayoutConstraint(
            item: view,
            attribute: .width,
            relatedBy: .equal,
            toItem: view,
            attribute: .height,
            multiplier: aspectRatio,
            constant: 0
        )

        constraint.priority = UILayoutPriority(rawValue: 999)
        view.addConstraint(constraint)
        aspectRatioConstraint = constraint
    }

    @objc
    private func stopPlayback(andResetUrl reset: Bool = true) {
        if reset {
            url = nil
        }
        playerObserver = nil
        playerView?.playerLayer.player = nil
        // Cancel the active task if it is running
        activeTask?.cancel()
        activeTask = nil
        mainImageView?.image = nil
    }
}

extension VideoUITableViewCell: GenericCellCacheProtocol {
    func invalidateCache() {
        url = nil
    }
}
