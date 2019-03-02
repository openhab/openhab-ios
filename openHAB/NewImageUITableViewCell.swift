//
//  NewImageUITableViewCell.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 16.02.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import UIKit

class NewImageUITableViewCell: UITableViewCell {

    var mainImageView: ScaledHeightImageView!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        mainImageView = ScaledHeightImageView()

        contentView.addSubview(mainImageView)

        let marginGuide = contentView.layoutMarginsGuide

        mainImageView.translatesAutoresizingMaskIntoConstraints = false // enable autolayout
        mainImageView.contentMode = .scaleAspectFit

        NSLayoutConstraint.activate([
            mainImageView.leftAnchor.constraint(equalTo: marginGuide.leftAnchor),
            mainImageView.rightAnchor.constraint(equalTo: marginGuide.rightAnchor),
            mainImageView.topAnchor.constraint(equalTo: marginGuide.topAnchor),
            mainImageView.bottomAnchor.constraint(equalTo: marginGuide.bottomAnchor)
            ])
    }

    required init?(coder aDecoder: NSCoder) {

        fatalError("init(coder:) has not been implemented")

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
