//
//  ScaledHeightUIImageView.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 26.02.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

/// An image view that computes its intrinsic height from its width while preserving aspect ratio
/// Source: https://stackoverflow.com/a/48476446
class ScaledHeightUIImageView: UIImageView {
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
