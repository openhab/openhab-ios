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
