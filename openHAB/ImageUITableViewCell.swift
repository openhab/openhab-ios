//  Converted to Swift 4 by Swiftify v4.2.28993 - https://objectivec2swift.com/
//
//  ImageUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 18/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

import SDWebImage

@objc protocol ImageUITableViewCellDelegate: NSObjectProtocol {
    func didLoadImageOf(_ cell: ImageUITableViewCell?)
}

var refreshTimer: Timer?

class ImageUITableViewCell: GenericUITableViewCell {
    var widgetImage: UIImageView?
    @objc weak var delegate: ImageUITableViewCellDelegate?

    func setWidget(_ widget: OpenHABWidget?) {
        super.widget = widget
        // Remove image from SDImage cache
    }

    override func displayWidget() {
        widgetImage = viewWithTag(901) as? UIImageView
        if widget?.image == nil {
            loadImage()
        } else {
            widgetImage?.image = widget?.image
        }
        // If widget have a refresh rate configured, schedule an image update timer
        if widget.refresh != nil && refreshTimer == nil {
            let refreshInterval = TimeInterval(widget.refresh.floatValue / 1000)
            refreshTimer = Timer.scheduledTimer(timeInterval: refreshInterval, target: self, selector: #selector(ImageUITableViewCell.refreshImage(_:)), userInfo: nil, repeats: true)
        }
    }

    func loadImage() {
        let random = Int(arc4random()) % 1000
        widgetImage?.sd_setImage(with: URL(string: "\(widget.url)&random=\(random)"), placeholderImage: nil, options: SDWebImageOptions.cacheMemoryOnly, completed: { image, error, cacheType, imageURL in
            self.widget?.image = image
            self.widgetImage?.frame = self.contentView.frame
            if self.delegate != nil {
                self.delegate?.didLoadImageOf(self)
            }
        })
    }

    @objc func refreshImage(_ timer: Timer?) {
        let random = Int(arc4random()) % 1000
        widgetImage?.sd_setImage(with: URL(string: "\(widget.url)&random=\(random)"), placeholderImage: widgetImage?.image, options: SDWebImageOptions.cacheMemoryOnly, completed: { image, error, cacheType, imageURL in
            self.widget?.image = image
            if self.delegate != nil {
                self.delegate?.didLoadImageOf(self)
            }
        })
    }

    func willMove(to newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil && refreshTimer != nil {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }
}
