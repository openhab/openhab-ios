//
//  NewImageUITableViewCell.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 16.02.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

//import Kingfisher
import os.log
import SDWebImage
import UIKit

protocol NewImageUITableViewCellDelegate: class {
    func didLoadImageOf(_ cell: NewImageUITableViewCell?)
}

class NewImageUITableViewCell: GenericUITableViewCell {

    var mainImageView: ScaledHeightImageView!
    var refreshTimer: Timer?

    weak var delegate: NewImageUITableViewCellDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        mainImageView = ScaledHeightImageView()

        contentView.addSubview(mainImageView)

        let positionGuide = contentView //contentView.layoutMarginsGuide if more margin would be appreciated

        mainImageView.translatesAutoresizingMaskIntoConstraints = false // enable autolayout
        mainImageView.contentMode = .scaleAspectFit

        NSLayoutConstraint.activate([
            mainImageView.leftAnchor.constraint(equalTo: positionGuide.leftAnchor),
            mainImageView.rightAnchor.constraint(equalTo: positionGuide.rightAnchor),
            mainImageView.topAnchor.constraint(equalTo: positionGuide.topAnchor),
            mainImageView.bottomAnchor.constraint(equalTo: positionGuide.bottomAnchor)
            ])
    }

    required init?(coder aDecoder: NSCoder) {

        fatalError("init(coder:) has not been implemented")

    }

    override func displayWidget() {
        if widget?.image == nil {
            loadImage()
        } else {
            mainImageView.image = widget?.image
        }
        // If widget have a refresh rate configured, i.e. different from zero, schedule an image update timer
        if widget.refresh != 0 {
            if refreshTimer != nil {
                refreshTimer?.invalidate()
                refreshTimer = nil
            }
            let refreshInterval = TimeInterval(Double(widget.refresh) / 1000)
            if refreshInterval > 0.09 {
                os_log("Sheduling image refresh every %g seconds", log: .viewCycle, type: .info, refreshInterval)
                refreshTimer = Timer.scheduledTimer(timeInterval: refreshInterval, target: self,
                                                    selector: #selector(NewImageUITableViewCell.refreshImage(_:)), userInfo: nil, repeats: true)
            }
        }
    }

    func createURL() -> URL {
        switch widget?.type {
//        case "Chart":
//            return Endpoint.chart(rootUrl: openHABRootUrl, period: widget!.period, type: widget!.item!.type, service: widget!.service, name: widget!.item!.name).url!
        case "Image":
            os_log("Image URL: %{PUBLIC}@", log: OSLog.urlComposition, type: .debug, widget.url)
            return URL(string: widget!.url)!
        default:
            return URL(string: "")!
        }
    }

    // https://github.com/SDWebImage/SDWebImage/wiki/Common-Problems#handle-self-capture-in-completion-block
    func loadImage() {
//        mainImageView?.kf.setImage(with: createURL(),
//                                   placeholder: UIImage(named: "blankicon.png"),
//                                   options: [.memoryCacheExpiration(.expired), .diskCacheExpiration(.expired)] ) { result in
//            switch result {
//            case .success(let value):
//                os_log("Download done for: %{PUBLIC}@", log: .urlComposition, type: .debug, value.source.url?.absoluteString ?? "")
//                self.widget?.image = value.image
//                self.layoutIfNeeded()
//                self.layoutSubviews()
//                if self.delegate != nil {
//                    self.delegate?.didLoadImageOf(self)
//                }
//            case .failure(let error):
//                os_log("Download failed: %{PUBLIC}@", log: .urlComposition, type: .debug, error.localizedDescription)
//            }
//        }
        let prefs = UserDefaults.standard
        let ignoreSSLCertificate = prefs.bool(forKey: "ignoreSSL")

        // See https://developer.apple.com/documentation/swift/optionset
        var imageOptions: SDWebImageOptions = .fromLoaderOnly
        if ignoreSSLCertificate {
            imageOptions.insert(.allowInvalidSSLCertificates)
        }
        mainImageView?.sd_setImage(with: createURL(), placeholderImage: UIImage(named: "blankicon.png"), options: imageOptions) { [weak self] (image, error, cacheType, imageURL) in
            self?.widget?.image = image
            self?.layoutIfNeeded()
            self?.layoutSubviews()
            if self?.delegate != nil {
                self?.delegate?.didLoadImageOf(self)
            }
        }
    }

    @objc func refreshImage(_ timer: Timer?) {
        os_log("Refreshing image on %g seconds schedule", log: .viewCycle, type: .info, Double(widget.refresh) / 1000)
        //  options: .cacheMemoryOnly
//        mainImageView?.kf.setImage(with: createURL(),
//                                   placeholder: widget?.image,
//                                   options: [.memoryCacheExpiration(.expired), .diskCacheExpiration(.expired)]) { result in
//            switch result {
//            case .success(let value):
//                os_log("Download done for: %{PUBLIC}@", log: .urlComposition, type: .debug, value.source.url?.absoluteString ?? "")
//                self.widget?.image = value.image
//                self.layoutIfNeeded()
//                self.layoutSubviews()
//                if self.delegate != nil {
//                    self.delegate?.didLoadImageOf(self)
//                }
//            case .failure(let error):
//                os_log("Download failed: %{PUBLIC}@", log: .urlComposition, type: .debug, error.localizedDescription)
//            }
//        }
        mainImageView?.sd_setImage(with: createURL(),
                                   placeholderImage: widget?.image,
                                   options: [.allowInvalidSSLCertificates,
                                             .fromLoaderOnly]) { [weak self] (image, error, cacheType, imageURL) in
            self?.widget?.image = image
            self?.layoutIfNeeded()
            self?.layoutSubviews()
            if self?.delegate != nil {
                self?.delegate?.didLoadImageOf(self)
            }
        }
    }
}

/// An image view that computes its intrinsic height from its width while preserving aspect ratio
/// Source: https://stackoverflow.com/a/48476446
class ScaledHeightImageView: UIImageView {

    // Track the width that the intrinsic size was computed for,
    // to invalidate the intrinsic size when needed
    private var layoutedWidth: CGFloat = 0

    override var intrinsicContentSize: CGSize {
        layoutedWidth = bounds.width
        if let image = self.image {
            let viewWidth = bounds.width
            let ratio = viewWidth / image.size.width
            return CGSize(width: viewWidth, height: image.size.height * ratio)
        }
        return super.intrinsicContentSize
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if layoutedWidth != bounds.width {
            invalidateIntrinsicContentSize()
        }
    }
}
