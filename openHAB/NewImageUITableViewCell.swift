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

    var mainImageView: ScaleAspectFitImageView!
    var refreshTimer: Timer?

    weak var delegate: NewImageUITableViewCellDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        mainImageView = ScaleAspectFitImageView()

        contentView.addSubview(mainImageView)

        let positionGuide = contentView //contentView.layoutMarginsGuide if more margin would be appreciated

        mainImageView.translatesAutoresizingMaskIntoConstraints = false // enable autolayout

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
            refreshTimer?.invalidate()
            refreshTimer = nil
            let refreshInterval = TimeInterval(Double(widget.refresh) / 1000)
            if refreshInterval > 0.09 {
                os_log("Sheduling image refresh every %g seconds", log: .viewCycle, type: .info, refreshInterval)
                refreshTimer = Timer.scheduledTimer(timeInterval: refreshInterval, target: self,
                                                    selector: #selector(NewImageUITableViewCell.refreshImage(_:)), userInfo: nil, repeats: true)
            }
        }
    }

    var createURL: URL {
        switch widget?.type {
        case "Chart":
            return Endpoint.chart(rootUrl: appData!.openHABRootUrl, period: widget!.period, type: widget!.item!.type, service: widget!.service, name: widget!.item!.name).url!
        case "Image":
            os_log("Image URL: %{PUBLIC}@", log: OSLog.urlComposition, type: .debug, widget.url)
            return URL(string: widget!.url)!
        default:
            return URL(string: "")!
        }
    }

    var appData: OpenHABDataObject? {
        return AppDelegate.appDelegate.appData
    }

    // https://github.com/SDWebImage/SDWebImage/wiki/Common-Problems#handle-self-capture-in-completion-block
    func loadImage() {
        mainImageView?.sd_setImage(with: createURL, placeholderImage: UIImage(named: "blankicon.png"), options: .imageOptionFromLoaderOnlyIgnoreInvalidCert) { [weak self] (image, error, cacheType, imageURL) in
            if let error = error {
                os_log("Download failed: %{PUBLIC}@", log: .urlComposition, type: .debug, error.localizedDescription)
                return
            }
            self?.widget?.image = image
            self?.delegate?.didLoadImageOf(self)
        }
    }

    @objc func refreshImage(_ timer: Timer?) {
        os_log("Refreshing image on %g seconds schedule", log: .viewCycle, type: .info, Double(widget.refresh) / 1000)
        mainImageView?.sd_setImage(with: createURL, placeholderImage: widget?.image, options: [.allowInvalidSSLCertificates, .fromLoaderOnly]) { [weak self] (image, error, cacheType, imageURL) in
            if let error = error {
                os_log("Download failed: %{PUBLIC}@", log: .urlComposition, type: .debug, error.localizedDescription)
                return
            }
            self?.widget?.image = image
            self?.delegate?.didLoadImageOf(self)
        }
    }
}
