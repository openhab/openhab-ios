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

enum VideoEncoding: String {
    case hls, mjpeg
}

class VideoUITableViewCell: GenericUITableViewCell {

    var didLoad: (() -> Void)?

    private var url: URL? {
        didSet {
            guard oldValue?.absoluteString != url?.absoluteString else { return }
            prepareToPlay()
        }
    }
    private var playerView: PlayerView!
    private var mainImageView: UIImageView!
    private let activityIndicator = UIActivityIndicatorView(style: .gray)
    private var playerObserver: NSKeyValueObservation?
    private var aspectRatioConstraint: NSLayoutConstraint?
    private var mjpegRequest: URLSessionDataTask?
    private var session: URLSession!
    private var imageData = Data()
    private var appData: OpenHABDataObject? {
        return AppDelegate.appDelegate.appData
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

        let marginGuide = contentView //contentView.layoutMarginsGuide if more margin would be appreciated
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
            playerObserver = playerItem.observe(\.status, options: [.new, .old]) { [weak self] (playerItem, _) in
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

        #warning("Verify whether this could be switched to Alamofire")

        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

        var streamRequest = URLRequest(url: url)
        streamRequest.timeoutInterval = 10.0

        mjpegRequest = session.dataTask(with: streamRequest)
        mjpegRequest?.resume()
    }

    private func updateAspectRatio(forView view: UIView?, aspectRatio: CGFloat) {
        guard let view = view else { return }

        if let constraint = aspectRatioConstraint {
            removeConstraint(constraint)
        }
        aspectRatioConstraint = nil

        let constraint = NSLayoutConstraint(item: view, attribute: .width,
                                            relatedBy: .equal,
                                            toItem: view, attribute: .height,
                                            multiplier: aspectRatio, constant: 0)

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
        self.mainImageView?.image = nil
    }
}

extension VideoUITableViewCell: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if !imageData.isEmpty, let image = UIImage(data: imageData) {
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
            imageData = Data()
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        imageData.append(data)
    }
}

extension VideoUITableViewCell: GenericCellCacheProtocol {
    func invalidateCache() {
        url = nil
    }
}
