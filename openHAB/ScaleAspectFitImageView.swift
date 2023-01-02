// Copyright (c) 2010-2023 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import UIKit

public class ScaleAspectFitImageView: UIImageView {
    private var aspectRatioConstraint: NSLayoutConstraint?
    override public var image: UIImage? {
        didSet {
            updateAspectRatioConstraint()
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    override public init(image: UIImage!) {
        super.init(image: image)
        setup()
    }

    override public init(image: UIImage!, highlightedImage: UIImage?) {
        super.init(image: image, highlightedImage: highlightedImage)
        setup()
    }

    private func setup() {
        contentMode = .scaleAspectFit
        updateAspectRatioConstraint()
    }

    /// Removes any pre-existing aspect ratio constraint, and adds a new one based on the current image
    private func updateAspectRatioConstraint() {
        if let constraint = aspectRatioConstraint {
            removeConstraint(constraint)
        }
        aspectRatioConstraint = nil

        if let imageSize = image?.size, imageSize.height != 0 {
            let aspectRatio = imageSize.width / imageSize.height
            let constraint = NSLayoutConstraint(
                item: self,
                attribute: .width,
                relatedBy: .equal,
                toItem: self,
                attribute: .height,
                multiplier: aspectRatio,
                constant: 0
            )

            constraint.priority = UILayoutPriority(rawValue: 999)
            addConstraint(constraint)
            aspectRatioConstraint = constraint
        }
    }
}
