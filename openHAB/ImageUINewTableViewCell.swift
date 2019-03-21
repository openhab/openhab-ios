//
//  ImageUINewTableViewCell.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 16.02.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import UIKit

class ImageUINewTableViewCell: GenericUITableViewCell {

    var fullImage: UIImage!

    var mainImageView : UIImageView  = {
        var imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.autoresizingMask = [.flexibleHeight]

        imageView.translatesAutoresizingMaskIntoConstraints = false

        imageView.clipsToBounds = true
        return imageView
    }()

    override func initialize() {
        selectionStyle = .none
        separatorInset = .zero
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.addSubview(mainImageView)
        mainImageView.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        mainImageView.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        mainImageView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        mainImageView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true

        initialize()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        initialize()
    }

    func aspectRatio() -> CGFloat? {
        if let height = fullImage?.size.height, let width = fullImage?.size.width {
            return height/width
        } else {
            return nil
        }
    }

    func createImageURL(with urlString: String) -> URL {
        let random = Int.random(in: 0..<1000)
        var components = URLComponents(string: urlString)
        components?.queryItems?.append(contentsOf: [
            URLQueryItem(name: "random", value: String(random))
            ])
        return components?.url ?? URL(string: "")!
    }

    func loadImage() {
        mainImageView.sd_setImage(with: createImageURL(with: widget.url), placeholderImage: nil) { [weak self] image, error, cacheType, imageURL in
            self?.widget.image = image
            self?.fullImage = image
            self?.setNeedsLayout()
            self?.layoutIfNeeded()
        }
    }

    override func displayWidget() {
        if widget?.image == nil {
            //loadImage()
        } else {
           // mainImageView.image = widget?.image
        }
        // If widget have a refresh rate configured, schedule an image update timer
//        if widget.refresh != "" && refreshTimer == nil {
//            let refreshInterval = TimeInterval(widget.refresh.floatValue / 1000)
//            refreshTimer = Timer.scheduledTimer(timeInterval: refreshInterval, target: self,
//                                                selector: #selector(ImageUITableViewCell.refreshImage(_:)), userInfo: nil, repeats: true)
//        }
    }
}
