// Copyright (c) 2010-2022 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Alamofire
import AVFoundation
import AVKit
import OpenHABCore
import os.log

enum VideoEncoding: String {
    case hls, mjpeg
}

class VideoUITableViewCell: GenericUITableViewCell {
    private var activityIndicator: UIActivityIndicatorView = {
        if #available(iOS 13.0, *) {
            return UIActivityIndicatorView(style: .medium)
        } else {
            return UIActivityIndicatorView(style: .gray)
        }
    }()

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
    private var mjpegRequest: Alamofire.Request?
    private var session: URLSession!
    private var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

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

        guard let url = url else {
            stopPlayback()
            return
        }

        if widget.encoding.lowercased() != VideoEncoding.mjpeg.rawValue {
            bringSubviewToFront(playerView)
            let playerItem = AVPlayerItem(asset: AVAsset(url: url))
            playerObserver = playerItem.observe(\.status, options: [.new, .old]) { [weak self] playerItem, _ in
                switch playerItem.status {
                case .failed:
                    os_log("Failed to load video with URL: %{PUBLIC}@", log: .urlComposition, type: .debug, url.absoluteString)
                    self?.url = nil
                case .readyToPlay:
                    os_log("Loaded video with URL: %{PUBLIC}@", log: .urlComposition, type: .debug, url.absoluteString)
                default: return
                }

                self?.activityIndicator.isHidden = true
                if playerItem.status == .readyToPlay, playerItem.presentationSize != .zero {
                    let aspectRatio = playerItem.presentationSize.width / playerItem.presentationSize.height
                    self?.updateAspectRatio(forView: self?.playerView, aspectRatio: aspectRatio)
                    self?.didLoad?()
                }
            }
            playerView?.playerLayer.player = AVPlayer(playerItem: playerItem)
        }
    }

    private func playMjpegStream() {
        guard let url = url else {
            stopPlayback()
            return
        }

        if mjpegRequest != nil {
            return
        }

        bringSubviewToFront(mainImageView)

        var streamRequest = URLRequest(url: url)
        streamRequest.timeoutInterval = 10.0

        let streamImageInitialBytePattern = Data([255, 216])
        var imageData = Data()
        mjpegRequest = NetworkConnection.shared.manager.streamRequest(streamRequest)
            .validate()
            .responseStream { stream in
                switch stream.event {
                case let .stream(result):
                    switch result {
                    case let .success(data):
                        if data.starts(with: streamImageInitialBytePattern) {
                            if let image = UIImage(data: imageData) {
                                DispatchQueue.main.async {
                                    if self.mainImageView?.image == nil {
                                        let aspectRatio = image.size.width / image.size.height
                                        self.activityIndicator.isHidden = true
                                        self.updateAspectRatio(forView: self.mainImageView, aspectRatio: aspectRatio)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                            self.didLoad?()
                                        }
                                    }
                                    self.mainImageView?.image = image
                                }
                            }
                            imageData = Data()
                        }
                        imageData.append(data)
                    }
                case let .complete(completion):
                    os_log("Failed to decode stream", log: .decoding, type: .debug, completion.error?.localizedDescription ?? "")
                }
            }

        mjpegRequest?.resume()
    }

    private func updateAspectRatio(forView view: UIView?, aspectRatio: CGFloat) {
        guard let view = view else { return }

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
        mjpegRequest?.cancel()
        mjpegRequest = nil
        mainImageView?.image = nil
    }
}

extension VideoUITableViewCell: GenericCellCacheProtocol {
    func invalidateCache() {
        url = nil
    }
}
