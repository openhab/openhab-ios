//
//  ImageUINewTableViewCell.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 16.02.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import UIKit

class ImageUINewTableViewCell: GenericUITableViewCell {

    var mainImageView : UIImageView  = {
        var imageView = UIImageView(frame: CGRect.init(x: 0, y: 0, width: 0, height: 0))
        imageView.contentMode = .scaleAspectFill // image will never be strecthed vertially or horizontally
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.addSubview(mainImageView)
        mainImageView.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        mainImageView.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        mainImageView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        mainImageView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        selectionStyle = .none
        separatorInset = .zero
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
        mainImageView.sd_setImage(with: imageURL(), placeholderImage: nil) { [weak self] image, error, cacheType, imageURL in
            self?.widget.image = image
            self?.setNeedsLayout()
            self?.layoutIfNeeded()
        }
    }

    override func displayWidget() {
        if widget?.image == nil {
            loadImage()
        } else {
            mainImageView.image = widget?.image
        }
        // If widget have a refresh rate configured, schedule an image update timer
        if widget.refresh != "" && refreshTimer == nil {
            let refreshInterval = TimeInterval(widget.refresh.floatValue / 1000)
            refreshTimer = Timer.scheduledTimer(timeInterval: refreshInterval, target: self,
                                                selector: #selector(ImageUITableViewCell.refreshImage(_:)), userInfo: nil, repeats: true)
        }
    }
}
