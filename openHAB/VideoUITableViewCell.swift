//
//  VideoUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 18/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import AVFoundation
import AVKit
import os.log

protocol VideoUITableViewCellDelegate: class {
    func didLoadVideoOf(_ cell: VideoUITableViewCell?)
}

class VideoUITableViewCell: UITableViewCell {

    var url: URL? {
        didSet {
            guard oldValue?.absoluteString != url?.absoluteString else { return }
            prepareToPlay()
        }
    }
    weak var delegate: VideoUITableViewCellDelegate?

    private(set) var playerView: PlayerView!
    private let activityIndicator = UIActivityIndicatorView(style: .gray)
    private var playerObserver: NSKeyValueObservation?
    private var aspectRatioConstraint: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        activityIndicator.hidesWhenStopped = true
        playerView = PlayerView()
        contentView.addSubview(playerView)
        contentView.addSubview(activityIndicator)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false // enable autolayout
        playerView.translatesAutoresizingMaskIntoConstraints = false // enable autolayout
        playerView.contentMode = .scaleAspectFit

        let marginGuide = contentView //contentView.layoutMarginsGuide if more margin would be appreciated
        NSLayoutConstraint.activate([
            playerView.leftAnchor.constraint(equalTo: marginGuide.leftAnchor),
            playerView.rightAnchor.constraint(equalTo: marginGuide.rightAnchor),
            playerView.topAnchor.constraint(equalTo: marginGuide.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: marginGuide.bottomAnchor)
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

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func prepareToPlay() {
        guard let url = url else {
            stopPlayback()
            return
        }

        activityIndicator.isHidden = false
        activityIndicator.startAnimating()

        let playerItem = AVPlayerItem(asset: AVAsset(url: url))
        playerObserver = playerItem.observe(\.status, options: [.new, .old], changeHandler: { [weak self] (playerItem, change) in
            switch playerItem.status {
            case .failed:
                os_log("Failed to load video with URL: %{PUBLIC}@", log: .urlComposition, type: .debug, url.absoluteString)
                self?.url = nil
            case .readyToPlay:
                os_log("Loaded video with URL: %{PUBLIC}@", log: .urlComposition, type: .debug, url.absoluteString)
            default: return
            }

            self?.activityIndicator.isHidden = true
            if playerItem.status == .readyToPlay, let self = self, let playerView = self.playerView {
                if let constraint = self.aspectRatioConstraint {
                    self.removeConstraint(constraint)
                }
                self.aspectRatioConstraint = nil

                if playerItem.presentationSize != .zero {
                    let aspectRatio = playerItem.presentationSize.width / playerItem.presentationSize.height
                    let constraint = NSLayoutConstraint(item: playerView, attribute: .width,
                                                        relatedBy: .equal,
                                                        toItem: playerView, attribute: .height,
                                                        multiplier: aspectRatio, constant: 0)

                    constraint.priority = UILayoutPriority(rawValue: 999)
                    self.playerView.addConstraint(constraint)
                    self.aspectRatioConstraint = constraint
                    self.delegate?.didLoadVideoOf(self)
                }
            }
        })

        playerView?.playerLayer.player = AVPlayer(playerItem: playerItem)
    }

    @objc private func stopPlayback() {
        url = nil
        playerObserver = nil
        playerView?.playerLayer.player = nil
    }
}
