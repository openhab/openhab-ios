//
//  ScaleAspectFitImageView.swift
//  openHAB
//
//  Created by weak on 27.06.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import UIKit

public class ScaleAspectFitImageView: UIImageView {
    private var aspectRatioConstraint: NSLayoutConstraint?
    override public var image: UIImage? {
        didSet {
            self.updateAspectRatioConstraint()
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public override init(image: UIImage!) {
        super.init(image: image)
        setup()
    }

    public override init(image: UIImage!, highlightedImage: UIImage?) {
        super.init(image: image, highlightedImage: highlightedImage)
        setup()
    }

    private func setup() {
        contentMode = .scaleAspectFit
        updateAspectRatioConstraint()
    }

    /// Removes any pre-existing aspect ratio constraint, and adds a new one based on the current image
    private func updateAspectRatioConstraint() {
        if let constraint = self.aspectRatioConstraint {
            removeConstraint(constraint)
        }
        aspectRatioConstraint = nil

        if let imageSize = image?.size, imageSize.height != 0 {
            let aspectRatio = imageSize.width / imageSize.height
            let constraint = NSLayoutConstraint(item: self, attribute: .width,
                                                relatedBy: .equal,
                                                toItem: self, attribute: .height,
                                                multiplier: aspectRatio, constant: 0)

            constraint.priority = UILayoutPriority(rawValue: 999)
            addConstraint(constraint)
            aspectRatioConstraint = constraint
        }
    }
}
