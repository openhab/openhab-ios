//
//  ImageUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 18/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import SDWebImage

protocol ImageUITableViewCellDelegate: NSObjectProtocol {
    func didLoadImageOf(_ cell: ImageUITableViewCell?)
}

var refreshTimer: Timer?

class ImageUITableViewCell: GenericUITableViewCell {
    @IBOutlet weak var widgetImage: UIImageView!
    weak var delegate: ImageUITableViewCellDelegate?

    @objc override var widget: OpenHABWidget! {
        get {
            return super.widget
        }
        set(widget) {
            super.widget = widget
            // Remove image from SDImage cache
        }
    }

    override func displayWidget() {
        if widget?.image == nil {
            loadImage()
        } else {
            widgetImage?.image = widget?.image
        }
        // If widget have a refresh rate configured, schedule an image update timer
        if widget.refresh != "" && refreshTimer == nil {
            let refreshInterval = TimeInterval(widget.refresh.floatValue / 1000)
            refreshTimer = Timer.scheduledTimer(timeInterval: refreshInterval, target: self,
                                                selector: #selector(ImageUITableViewCell.refreshImage(_:)), userInfo: nil, repeats: true)
        }
    }

    func imageURL() -> URL {
        let random = Int.random(in: 0..<1000)
        var components = URLComponents(string: widget.url)
        components?.queryItems?.append(contentsOf: [
            URLQueryItem(name: "random", value: String(random))
            ])
        return components?.url ?? URL(string: "")!
    }

    func loadImage() {
        widgetImage?.sd_setImage(with: imageURL(), placeholderImage: nil) { (image, error, cacheType, imageURL) in
            // Perform operation.
            self.widget.image = image
            self.widgetImage.frame = self.contentView.frame
            if self.delegate != nil {
                self.delegate?.didLoadImageOf(self)
            }
        }
    }

    @objc func refreshImage(_ timer: Timer?) {
        widgetImage?.sd_setImage(with: imageURL(), placeholderImage: widgetImage?.image)
    }

    func willMove(to newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil && refreshTimer != nil {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }
}
